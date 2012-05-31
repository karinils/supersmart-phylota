#!/usr/bin/perl

# Submits a bunch of pb_crawlNCBI.feature... jobs to the cluster, one for each taxon id node listed in the table infile
# That file expects tab delim table in which the ti is the first column.

# USAGE: .. -f magicfile -c configfile -feature feature_type

use Getopt::Long;

my $featureType= 'cds'; # default data type is cds;
my $infile="";
my $configFile = "pb.conf.feature";

my $result = GetOptions ("f=s" => \$infile,
			 "c=s" => \$configFile, 
			 "feature=s" => \$featureType); 


open FH, "<$infile";
while (<FH>)
	{
	@cols=split;
	push @tis, $cols[0];
	}
close FH;
for $ti (@tis)	

	{
	$s=" qsub pb_crawlNCBI.feature.pl -t $ti -c $configFile -feature $featureType";
	#print "$s\n";
	system $s;
	}
