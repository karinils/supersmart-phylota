#!/usr/bin/perl -w

# A supernumerary cluster is a cluster that has one child cluster and is identical to that cluster.
# Find these by visiting each cluster and checking its parent.
# NB. Currently WE ONLY CHECK PI CLUSTERS, ignoring all those node and non-PI clusters that won't go to SearchTree anyway.
# Note the parent of a SN cluster might itself not be SN. It does not necessarily propogate toward root.

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


my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

#### MAKE THIS RIGHT WITH RESPECT TO PI AND CL_TYPE IN QUERIES THROUGHOUT!

$sql = "select ci,ti_root,ti_anc,ci_anc,n_gi from $clusterTable,$nodeTable where ti_root=ti and PI=1 and ci_anc IS NOT NULL limit 100 ";
print "$sql\n";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
		$ci=$H->{ci};
		$ti=$H->{ti_root};
		$ci_anc=$H->{ci_anc};
		$ti_anc=$H->{ti_anc};
		$ngi=$H->{n_gi};

# ...always have to search using cl_type key along with the other two keys, but above we could just retrieve with PI
# ...also note that if the parent's supernum status has been determined already (IS NOT NULL), we do not need to check
# ...because whether it is or is not supernum with respect to some other child of this parent, 
#    this is determinative for all children
		$sqls = "select n_gi,supernum from $clusterTable where ci=$ci_anc and ti_root=$ti_anc and cl_type='subtree'";
		$shs = $dbh->prepare($sqls);
		$shs->execute;
		if ($Hs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
			{
			$ngi_anc=$Hs->{n_gi};
			if ($ngi == $ngi_anc)
				{
				++$matchCount;
				$s="update $clusterTable set supernum=1 where ti_root=$ti_anc and ci=$ci_anc and cl_type='subtree'";
				}
			else
				{
				++$nomatchCount;
				$s="update $clusterTable set supernum=0 where ti_root=$ti_anc and ci=$ci_anc and cl_type='subtree'";
#				print "$ci\t$ti\t$sxn :: $s\n" ;
				}
			$dbh->do($s) or die $dbh->errstr;
			}
		else
			{
			print "Nothing returned from $sqls\n";
			}
		$shs->finish;
		++$clusterCount;
#print "$clusterCount $matchCount\n";
#		print "$clusterCount\n" if ($clusterCount % 1000 == 0);
	}
$sh->finish;
print "Match count = $matchCount / $clusterCount (no match=$nomatchCount)\n";
