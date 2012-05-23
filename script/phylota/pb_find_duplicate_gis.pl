#!/usr/bin/perl -w

use DBI;
use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

# mysql database info

$gb_rel=$release; # current release we are using

$cigiTable="ci_gi_$release";


my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$count=0;
$sh = $dbh->prepare("select * from $cigiTable"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  
	{ 
	$ti =$rowHRef->{ti}; 
	$clustid =$rowHRef->{clustid}; 
	$cl_type =$rowHRef->{cl_type}; 
	$gi =$rowHRef->{gi}; 
	$key = "$ti\_$clustid\_$cl_type\_$gi";
	if ($seen{$key})
		{
		print "$key is a duplicate\n";
		++$count;
		$tiH{$ti}=1;
		}
	else
		{
		$seen{$key}=1;
		}
	}
$sh->finish;

$nti=keys %tiH;
print "There were $count duplicate gis among $nti distinct tis\n";
