#!/usr/bin/perl -w

# Query the phylota database to make some summary stats; store these in the summary_stats table for later access

use DBI;
use pb;

$alignments_done = 0;
$trees_done = 0; # initially we'll record that these are not done yet at the time this script is run

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$gb_rel_date = pb::currentGBReleaseDate();

$nodeTable="nodes_$release";

# mysql database info

$gb_rel=$release; # current release we are using

$tableName="summary_stats";
$clusterTable="clusters_$release";


my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

#$s="drop table if exists $tableName";
#$dbh->do("$s");
$s="create table if not exists $tableName (
		gb_release INT UNSIGNED,
		gb_rel_date VARCHAR(25),
		n_gis INT UNSIGNED,
		n_nodes INT UNSIGNED,
		n_nodes_term INT UNSIGNED,
		n_clusts_node INT UNSIGNED,
		n_clusts_sub  INT UNSIGNED,
		n_nodes_with_sequence  INT UNSIGNED,
		n_clusts INT UNSIGNED,
		n_PI_clusts INT UNSIGNED,
		n_singleton_clusts INT UNSIGNED,
		n_large_gi_clusts INT UNSIGNED,
		n_large_ti_clusts INT UNSIGNED,
		n_largest_gi_clust INT UNSIGNED,
		n_largest_ti_clust INT UNSIGNED,
		alignments_done BOOLEAN,
		trees_done BOOLEAN
		) ";
$dbh->do("$s");

$sh = $dbh->prepare("select count(*) from seqs"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $numGIs =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select count(*) from $nodeTable "); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $numNodes =$rowHRef->{'count(*)'}; }
$sh->finish;
$sh = $dbh->prepare("select count(*) from $nodeTable where terminal_flag=1"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $numTerms =$rowHRef->{'count(*)'}; }
$sh->finish;
$sh = $dbh->prepare("select count(*) from $nodeTable where n_clust_node>0"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $nodesWithClusts =$rowHRef->{'count(*)'}; }
$sh->finish;
$sh = $dbh->prepare("select count(*) from $nodeTable where n_clust_sub>0"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $nodesWithClustsSub =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select count(*) from $nodeTable where n_gi_node>0 || n_gi_sub_nonmodel>0"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $nodesWithSequence =$rowHRef->{'count(*)'}; } # nodes with short sequence at node proper or short nonmodel seq at subtree
$sh->finish;

$sh = $dbh->prepare("select count(*) from $clusterTable "); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_clusts =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select count(*) from $clusterTable where PI=1"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_PI_clusts =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select count(*) from $clusterTable where n_gi=1"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_singleton_clusts =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select count(*) from $clusterTable where n_gi>=100"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_large_gi_clusts =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select count(*) from $clusterTable where n_ti>=100"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_large_ti_clusts =$rowHRef->{'count(*)'}; }
$sh->finish;

$sh = $dbh->prepare("select max(n_gi) from $clusterTable"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_largest_gi_clust =$rowHRef->{'max(n_gi)'}; }
$sh->finish;

$sh = $dbh->prepare("select max(n_ti) from $clusterTable"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $n_largest_ti_clust =$rowHRef->{'max(n_ti)'}; }
$sh->finish;


$s = "insert into $tableName values($gb_rel,\'$gb_rel_date\',$numGIs,$numNodes,$numTerms,$nodesWithClusts,$nodesWithClustsSub,$nodesWithSequence,$n_clusts,$n_PI_clusts,$n_singleton_clusts,$n_large_gi_clusts,$n_large_ti_clusts,$n_largest_gi_clust,$n_largest_ti_clust,$alignments_done,$trees_done)";
print "$s\n";
$dbh->do("$s");

