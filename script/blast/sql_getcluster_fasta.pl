#!/usr/bin/perl

# Script to retrieve a cluster from pb directly

use DBI;

use pb;
# DBOSS
while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl eq '-c') {$configFile = $par;}
  if ($fl eq '-r') {$release = $par;}
  if ($fl eq '-ti') {$tiNode = $par;}
  if ($fl eq '-cl') {$cluster = $par;}
  if ($fl eq '-ntype') {$nquery = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$database=$release;
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$tablename="nodes_$release";
$clusterTable = "ci_gi_$release";



$sql="select seqs.gi,seqs.seq,seqs.def from seqs,$clusterTable where $clusterTable.ti=$tiNode and $clusterTable.clustid=$cluster and seqs.gi=$clusterTable.gi and cl_type='$nquery'";
$sh = $dbh->prepare($sql);
$sh->execute;
$fastaLen=80;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$gi =$rowHRef->{gi};
	$def=$rowHRef->{def};
	$seq=$rowHRef->{seq};
	print ">gi|$gi|$def\n";
	$len=length($seq);
	for ($i=0;$i<$len;$i+=$fastaLen)
		{
		print substr ($seq,$i,$fastaLen);
		print "\n";
		}
	}
$sh->finish;

