#!/usr/bin/perl

# At a given node in the PB tree, deliver the clustid x taxon id coverage matrix in edge format
# clustid taxid weight


use DBI;
use pb;
$weight=1.0;
$PI=1;	# default to retrieve only PI clusters

while ($fl = shift @ARGV)
  {
  if ($fl eq '-c') {$configFile = shift @ARGV;}
  if ($fl eq '-r') {$release = shift @ARGV;}
  if ($fl eq '-ti') {$tiNode = shift @ARGV;}
  }
# Initialize a bunch of locations, etc.

%pbH=%{pb::parseConfig($configFile)};
$database=$release;
$cigiTable = "ci_gi_$release";
$clusterTable = "clusters_$release";
$nQuery = 'subtree';


# Temporary files created with job ids to make them unique to process

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$sql="select ti,clustid,ti_of_gi from $clusterTable,$cigiTable where ti_root=$tiNode and PI=$PI and $clusterTable.cl_type='$nQuery' and ti=ti_root and ci=clustid";

$sh = $dbh->prepare($sql);
$sh->execute;
while (($ti,$clustid,$ti_of_gi) = $sh->fetchrow_array)  
	{
	print "$clustid\t$ti_of_gi\t$weight\n";
	}
$sh->finish;
