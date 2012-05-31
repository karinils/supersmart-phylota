#!/usr/bin/perl

# Script to retrieve a cluster from pb directly

use DBI;

use pb;
# DBOSS

$nquery='subtree'; # default
$lcutoff=0; # aa length minimum (>= lcutoff)

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl eq '-c') {$configFile = $par;}
  if ($fl eq '-ti') {$tiNode = $par;}
  if ($fl eq '-cl') {$cluster = $par;}
  if ($fl eq '-ntype') {$nquery = $par;}
  if ($fl eq '-lcutoff') {$lcutoff = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$tablename="nodes_$release";
$cigiTable = "ci_gi_$release";
$seqTable = "aas";



#$sql="select seqs.gi,seqs.seq,seqs.def from seqs,$clusterTable where $clusterTable.ti=$tiNode and $clusterTable.clustid=$cluster and seqs.gi=$clusterTable.gi and cl_type='$nquery'";

$sql="select $seqTable.gi,gi_aa,seq_aa,length_aa from $cigiTable,$seqTable where ti=$tiNode and clustid=$cluster and $seqTable.gi=$cigiTable.gi and cl_type='$nquery' and length_aa>=$lcutoff";

$sh = $dbh->prepare($sql);
$sh->execute;
$fastaLen=80;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$gi =$rowHRef->{gi};
	$gi_aa=$rowHRef->{gi_aa};
	$seq=$rowHRef->{seq_aa};
	print ">gi$gi\_giaa$gi_aa\n";
	$len=$rowHRef->{length_aa};
	for ($i=0;$i<$len;$i+=$fastaLen)
		{
		print substr ($seq,$i,$fastaLen);
		print "\n";
		}
	}
$sh->finish;

