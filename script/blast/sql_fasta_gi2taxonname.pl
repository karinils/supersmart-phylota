#!/usr/bin/perl

# Script to format and display a tree from the database as a nexus file. 

use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;



while ($fl = shift @ARGV)
  {
  if ($fl eq '-c') {$configFile = shift @ARGV;}
  }
# Initialize a bunch of locations, etc.

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;
$clusterTable = "clusters_$release";
$seqTable = "seqs";
$nodeTable= "nodes_$release";
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

while (<>)
	{
	if (/^[>]*(gi|gi\||)(\d+)(.*)/)  #either gi|XX ... giXX .. or XX
		{
		($ti,$name) = lookup ($2);
		print ">$name\_$1$2\_ti$ti\_$3\n";
		$tiH{$ti}++;
		$name =~ s/'//g;
		($genus)=split ' ', $name;
		$genusH{$genus}++;
		$count++;
		}
	else
		{print}
	}

$numTI = keys %tiH;
$numGen= keys %genusH;

print "$count records: Unique TIs=$numTI; Unique genera = $numGen\n";

sub lookup

{
	my ($gi,$outFormat)=@_;

	$sqls="select $nodeTable.ti,taxon_name from $nodeTable,$seqTable where $nodeTable.ti=$seqTable.ti and gi=$gi";
die "$sqls\n";
	$shs = $dbh->prepare($sqls);
	$shs->execute;
	my ($ti,$name) = $shs->fetchrow_array;
	$name =~ s/\'//g; # hack to fix single quotes in cur db
	$name = $dbh->quote($name);
	$shs->finish;
	my $formatted_label = "$name\_$gi\_$ti";
	return ($ti,$name,$formatted_label);
}
