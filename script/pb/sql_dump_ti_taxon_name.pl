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

$nodeTable="nodes\_$release";
$fn = "pb.dmp.ti_name.$release";
die "Refusing to overwrite existing file $fn\n" if (-e $fn);
open FH, ">$fn" or die;

# ************************************************************

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


$sql="select ti,taxon_name from $nodeTable";


$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$ti =$rowHRef->{ti};
	$name =$rowHRef->{taxon_name};
	
	print FH "$ti\t$name\n";
	}
$sh->finish;
close FH;
