#!/usr/bin/perl

# Dumps a two column tab-delimited table of gis and tis based on the database

use DBI;
use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
die if (!($configFile));

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

# ************************************************************

$seqTable="seqs";
$fn = "pb.dmp.giti.$release";
die "Refusing to overwrite existing file $fn\n" if (-e $fn);
open FH, ">$fn" or die;

# ************************************************************

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


$sql="select ti,gi from $seqTable";


$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$ti =$rowHRef->{ti};
	$gi =$rowHRef->{gi};
	
	print FH "$gi\t$ti\n";
	}
$sh->finish;
close FH;
