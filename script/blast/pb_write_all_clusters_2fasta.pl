#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=1G
#$ -l h_vmem=1G
#$ -M sanderm@email.arizona.edu
#$ -m e

# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes

# sge script to write all PI clusters as fasta files

use DBI;

use pb;
use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)

my $configFile= "/home/sanderm/blast/pb.conf"; #default
#while (my $fl = shift @ARGV)
#  {
#  my $par = shift @ARGV;
#  if ($fl =~ /-c/) {$configFile = $par;}
#  }
if (!(-e $configFile))
	{ die "Missing config file\n"; }

%pbH=%{pb::parseConfig($configFile)};
$fastaDir=$pbH{UNALIGNED_DIR};
$release=pb::currentGBRelease();

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



$cigiTable = "ci_gi_$release";
$clusterTable = "clusters_$release";

$nquery="\'subtree\'"; # this is required as long as you are selecting on PI clusters
$fastaLen=80;


$sql="select ti_root, ci from $clusterTable where PI=1";

$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$tiRoot =$rowHRef->{ti_root};
	$ci =$rowHRef->{ci};
	push @tiRoots,$tiRoot;
	push @cis,$ci;
	}
$sh->finish;

$numReturned = @tiRoots;

for ($j=0;$j<$numReturned;$j++)
	{
	$tiRoot=$tiRoots[$j];
	$ci=$cis[$j];

	$fn = "$fastaDir/ti$tiRoot\_ci$ci.fa";
	open FH, ">$fn";

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
	}
