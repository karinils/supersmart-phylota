#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=1G
#$ -l h_vmem=1G
#$ -M sanderm@email.arizona.edu
#$ -m e


# sge script to do a bunch of alignments as part of an SGE array job
# We will have already written a file that has the pair of keys corresponding to all the clusters in the database that we want
# This script will get one pair, then build the fasta file (temporarily) for this cluster, then do the alignment and save...

# CAREFUL THAT THE TASK ID DOESN'T EXCEED 120000; HAVE TO WORK ON THIS...

use DBI;
use pb;
use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)

my $configFile= "/home/sanderm/blast/pb.conf"; #default
if (!(-e $configFile))
	{ die "Missing config file\n"; }

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

$clusterListFn = "$pbH{ALIGNED_DIR}/clustersToBeAlignedList\_$release";
open FH, "<$clusterListFn";
$count=1;
while (<FH>)
	{
	if ($count++ == $ENV{SGE_TASK_ID})
		{
		($tiRoot,$ci)=split;
		last;
		}
	}
close FH;

$cigiTable = "ci_gi_$release";

$nquery="\'subtree\'"; # this is required in queries of ci_gi table as long as you are selecting on PI clusters
$fastaLen=80;

$unalignedFn = "$pbH{ALIGNED_DIR}/temp.fa";
open FH, ">$unalignedFn";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$sql="select seqs.gi,seqs.seq from seqs,$cigiTable where $cigiTable.ti=$tiRoot and $cigiTable.clustid=$ci and seqs.gi=$cigiTable.gi and cl_type=$nquery";

$sh = $dbh->prepare($sql);
$sh->execute;
$fastaLen=80;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
		{
		$gi =$rowHRef->{gi};
		$seq=$rowHRef->{seq};
		print FH ">gi|$gi\n";
		$len=length($seq);
		for (my $i=0;$i<$len;$i+=$fastaLen)
			{
			print FH substr ($seq,$i,$fastaLen);
			print FH "\n";
			}
		}
$sh->finish;
close FH;
