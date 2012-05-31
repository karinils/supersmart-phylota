#!/usr/bin/perl

# Script to retrieve a cluster from pb directly

use DBI;
use pb;
while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl eq '-c') {$configFile = $par;}
  if ($fl eq '-o') {$faFile = $par;}
  if ($fl eq '-length') {$lengthFile = $par;}
  }

open FHo, ">$faFile" or die "No fasta outfile specified\n";
open FHlen, ">$lengthFile" or die "No length outfile specified\n";

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$nodeTable="nodes_$release";
$clusterTable = "clusters_$release";


$sql = "select taxon_name,seed_gi,length,seq from seqs, $nodeTable, $clusterTable  where seqs.gi=seed_gi and PI=1 and $clusterTable.ti_root=$nodeTable.ti and rank='genus' ";



$sh = $dbh->prepare($sql);
$sh->execute;
$fastaLen=80;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$seed_gi =$rowHRef->{seed_gi};
	$length=$rowHRef->{length};
	$seq=$rowHRef->{seq};
	$taxon_name=$rowHRef->{taxon_name};
	print FHo ">$seed_gi\n";
	print FHlen "$seed_gi\t$length\n";
	for ($i=0;$i<$length;$i+=$fastaLen)
		{
		print FHo substr ($seq,$i,$fastaLen);
		print FHo "\n";
		}
	}
$sh->finish;

