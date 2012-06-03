# this is a legacy script file from phylota
#!/usr/bin/perl -w

# USAGE: ./sql_make_anc_cl.pl database_name

# Adds a column to the cluster table that points to each clusters parent cluster;
# that is, the cluster at the parent taxonomy node that contains the sequences in this cluster (and others)

# NOTE: we do not try to find parent clusters for model taxa node clusters

# Script alters the existing table and uses a cryptic select to get the basic data from which the parent can be found
# Script will run much faster if the ti field in the clusters_subtrees table is indexed. I added this manually 
# prior to running.

# i.e., ALTER TABLE clusters_subtrees ADD INDEX (ti);
# i.e., ALTER TABLE clusters_nodes ADD INDEX (ti);

use DBI;

use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

$clusterTable="clusters_$release";
$cigiTable="ci_gi_$release";
$nodeTable="nodes_$release";

# **** FOR TESTING PURPOSES ....

	$clusterTable .= "_test";
	$cigiTable    .= "_test";
	$nodeTable    .= "_test";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


$count=0;
$modelCount=0;

## Just use seed_gi...

$sql = "select ti, ti_anc, model,ci,cl_type,seed_gi from $nodeTable,$clusterTable where $nodeTable.ti=$clusterTable.ti_root;";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
	$model=$H->{model};
	if (!($node || $model))  # proceed UNLESS it's both a model organism and we're doing the node clusters
		{
		$ti_anc=$H->{ti_anc};
		$ti=$H->{ti};
		$seed_gi=$H->{seed_gi};
		$ci=$H->{ci};
		$cl_type=$H->{cl_type};

		# notice here to get the ancestor, we'll want to look in the subtree clusters always
		$sqls = "select clustid from $cigiTable where ti=$ti_anc and cl_type=\'subtree\' and gi=$seed_gi";
		$shs = $dbh->prepare($sqls);
		$shs->execute;
		while ($Hs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
			{
			$ci_anc=$Hs->{clustid};
			$s="update $clusterTable set ci_anc=$ci_anc where ti_root=$ti and ci=$ci and cl_type=\'$cl_type\'";
#print "$count updates done\n" if ($count/10000 == int($count/10000)); $count++;
#print "$s\n";
			$dbh->do($s);
			}
		$shs->finish;
		}
	else
		{++$modelCount;}
	}
$sh->finish;

