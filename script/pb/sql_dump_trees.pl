#!/usr/bin/perl

# write a text dump from PB for Duhong's tree database search code
# by default this strips any imbedded bootstrap values like ')XX.XXX' from the TDs.

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

$clusterTable="clusters" ."\_$release";

$treeField = "clustalw_tree"; # field in table having tree

$fn = "pb.dmp.trees.$release";
die "Refusing to overwrite existing file $fn\n" if (-e $fn);
open FH, ">$fn" or die;


# ************************************************************

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


$sql="select ti_root,ci,$treeField from $clusterTable where $treeField IS NOT NULL "; 

$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$td =$rowHRef->{$treeField};
	$ti =$rowHRef->{ti_root};
	$ci =$rowHRef->{ci};
	$td = strip ($td);	
	print FH "ti$ti\_cl$ci\t$td\n";  # Must be tiXX_clXXX to be compatible with Duhong
#die if (++$count>10);
	}
$sh->finish;
close FH;

sub strip  # strip bootstrap values
{
my ($S)=@_;
$S =~ s/\)\d+\.*\d*/\)/g;
return $S;
}
