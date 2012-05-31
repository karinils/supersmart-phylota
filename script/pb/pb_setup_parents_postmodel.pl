#!/usr/bin/perl -w

# Setups the parent nodes for node clusters of model organisms AFTER those model
# orgs have been added to the database via the usual scripts

use DBI;
use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
die "Specify configuration file\n" if (!$configFile);



%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

$clusterTable="clusters_$release";
$cigiTable="ci_gi_$release";
$nodeTable="nodes_$release";

# ******************************

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

print "Finding parent clusters of model organisms...\n";

$count=1;

$sql = "select ti, ti_anc, model,ci,cl_type,seed_gi from $nodeTable,$clusterTable where $nodeTable.ti=$clusterTable.ti_root and model=1 and cl_type='node';";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
	$cl_type=$H->{cl_type};
	$ti_anc=$H->{ti_anc};
	$ti=$H->{ti};
	$seed_gi=$H->{seed_gi};
	$ci=$H->{ci};

	# notice here to get the ancestor, we'll want to look in the subtree clusters always
	$sqls = "select clustid from $cigiTable where ti=$ti_anc and cl_type=\'subtree\' and gi=$seed_gi";
	$shs = $dbh->prepare($sqls);
	$shs->execute;
	while ($Hs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
			{
			$ci_anc=$Hs->{clustid};
			$s="update $clusterTable set ci_anc=$ci_anc where ti_root=$ti and ci=$ci and cl_type=\'$cl_type\'";
			print "$count parent cluster updates done\n" if ($count/10000 == int($count/10000)); $count++;
			$dbh->do($s);
			# 4/3/2012 added following snippet to deal with parent number of children
			$sqlss = "select n_child from $clusterTable where ti_root=$ti_anc and ci=$ci_anc and cl_type=\'subtree\'";
			$shss = $dbh->prepare($sqlss);
			$shss->execute;
			($nchild) = $shss->fetchrow_array;
			if (!defined ($nchild)) {$nchild=0};
			++$nchild;
			$s="update $clusterTable set n_child=$nchild where ci=$ci_anc and ti_root=$ti_anc and cl_type=\'subtree\'";

			}
	$shs->finish;
	}
$sh->finish;

