#!/usr/bin/perl

# USAGE: pb_put_trees.pl -c configFile -t treeFile

# Read a file with tree descriptions and insert into phylota db along with CFI
# Format of treefile:

# filename  tree description

# The filename should have a string imbedded that allows for extraction of the node and cluster ids
# such as ...ti###_ci#### (look for the regex below).

# UPDATED APRIL 2012 for new tree format of optimal RAXML tree with branch lengths.


use File::Spec;
use DBI;


use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl eq '-c') {$configFile = $par;}
  if ($fl eq '-f') {$treeFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$clusterTable = "clusters_$release";
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



$treeField="muscle_tree";

guts();

sub guts
{

	open FH, "<$treeFile" or die "Tree file not found\n";
	while (<FH>)
		{
		($fn,$Tree) = split;
		($ti,$cl)=($fn=~/ti(\d+)_ci(\d+)/);
		$s="update $clusterTable set $treeField=\'$Tree\' where ti_root=$ti and ci=$cl and cl_type='subtree'"; 
		#print "$s\n";
		$dbh->do($s);
#		die if (++$count>10);
		}
	close FH;
}


