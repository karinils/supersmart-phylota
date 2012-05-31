#!/usr/bin/perl -w
# Uses a nasty MySQL query of the nodes and clusters_subtrees tables to setup the cluster_table
# which has summary stats on every cluster
# Also updates the node table using the results form the cluster table
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
}
die "Specify configuration file\n" if ( !$configFile );
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$seqsTable    = "seqs";
$clusterTable = "clusters_$release";
$cigiTable    = "ci_gi_$release";
$nodeTable    = "nodes_$release";

# ******************************
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$s = "drop table if exists $clusterTable";
$dbh->do("$s");
$s = "create table if not exists $clusterTable(
		ti_root INT UNSIGNED,
		ci INT UNSIGNED, 
		cl_type ENUM('node','subtree'),
		INDEX(ti_root,ci,cl_type), 
		n_gi INT UNSIGNED, 
		n_ti INT UNSIGNED, 
		PI BOOL,		# if its phylogenically informative
		MinLength INT UNSIGNED,
		MaxLength INT UNSIGNED,
		MaxAlignDens FLOAT,
		ci_anc INT UNSIGNED,
		seed_gi BIGINT UNSIGNED,
		Q FLOAT,
		TC FLOAT,
		clustalw_tree LONGTEXT,
		muscle_tree LONGTEXT,
		strict_tree LONGTEXT,
		clustalw_res FLOAT,
		muscle_res FLOAT,
		strict_res FLOAT,
		ortho TINYINT, 		# 1 = orthologous cluster
		n_gen INT UNSIGNED,
		n_child INT UNSIGNED		# number of child clusters
		) ";

# .......................................................
print "Building cluster table...\n";
$dbh->do("$s");
$s =
"INSERT INTO $clusterTable select $cigiTable.ti,clustid,cl_type, count($cigiTable.gi),count(distinct $seqsTable.ti), count(distinct $seqsTable.ti)>=4, min(length),max(length), sum(length)/(max(length)*count($cigiTable.gi)),NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL from $seqsTable,$cigiTable where $cigiTable.gi=$seqsTable.gi group by $cigiTable.ti,clustid,cl_type";

#print "$s\n";
$dbh->do("$s");

# SHOULD PERHAPS WAIT ON THESE CALCULATIONS UNTIL AFTER MODEL ORGS ARE DONE, BECAUSE THEY HAVE TO BE
# UPDATED AGAIN TO REFLECT THE MODELS.
# .......................................................
# Now populate the seed gi
print "Adding seed gi values...\n";
$count = 1;

# following query delivers one gi for the group of gis formed by every combination of ti x clustid
$sql = "select ti_root, ci,cl_type from $clusterTable";
$sh  = $dbh->prepare($sql);
$sh->execute;
while ( $H = $sh->fetchrow_hashref ) {
    $ti      = $H->{ti_root};
    $clustid = $H->{ci};
    $cl_type = $H->{cl_type};

    # BUG FOUND 4/3/2012. I neglected to add cl_type key to this select
    $sqls =
"select $seqsTable.gi from $seqsTable,$cigiTable where $cigiTable.ti=$ti and $cigiTable.clustid=$clustid and $cigiTable.cl_type=\'$cl_type\' and $seqsTable.gi=$cigiTable.gi order by length desc limit 1";
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    while ( $Hs = $shs->fetchrow_hashref
      )    # only returns one row (presumably) here and next...
    {
        $gi = $Hs->{gi};
        $s =
"update $clusterTable set seed_gi=$gi where ti_root=$ti and ci=$clustid and cl_type=\'$cl_type\'";
        print "$count seed_gi updates done\n"
          if ( $count / 10000 == int( $count / 10000 ) );
        $count++;
        $dbh->do($s);
    }
    $shs->finish;
}
$sh->finish;

# .......................................................
# Now figure out the parent clusters ...
# NOTE: we save some computing and do not try to find parent clusters for model taxa node clusters
# Script will run much faster if the ti field in the clusters_subtrees table is indexed. I added this manually
# prior to running.
# i.e., ALTER TABLE clusters_subtrees ADD INDEX (ti);
# i.e., ALTER TABLE clusters_nodes ADD INDEX (ti);
print "Finding parent clusters...\n";
$count = 1;
$sql =
"select ti, ti_anc, model,ci,cl_type,seed_gi from $nodeTable,$clusterTable where $nodeTable.ti=$clusterTable.ti_root;";
$sh = $dbh->prepare($sql);
$sh->execute;
while ( $H = $sh->fetchrow_hashref ) {
    $model   = $H->{model};
    $cl_type = $H->{cl_type};
    next
      if ( $cl_type eq 'node' && $model )
      ; # skip the node clusters of model organisms; they don't have parent clusters (well, not at this stage of the pipeline...
    $ti_anc  = $H->{ti_anc};
    $ti      = $H->{ti};
    $seed_gi = $H->{seed_gi};
    $ci      = $H->{ci};

# notice here to get the ancestor, we'll want to look in the subtree clusters always
    $sqls =
"select clustid from $cigiTable where ti=$ti_anc and cl_type=\'subtree\' and gi=$seed_gi";
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    while ( $Hs = $shs->fetchrow_hashref
      )    # only returns one row (presumably) here and next...
    {
        $ci_anc = $Hs->{clustid};
        $s =
"update $clusterTable set ci_anc=$ci_anc where ti_root=$ti and ci=$ci and cl_type=\'$cl_type\'";
        $dbh->do($s);
        $sqlss =
"select n_child from $clusterTable where ti_root=$ti_anc and ci=$ci_anc and cl_type=\'subtree\'";
        $shss = $dbh->prepare($sqlss);
        $shss->execute;
        ($nchild) = $shss->fetchrow_array;
        if ( !defined($nchild) ) { $nchild = 0 }
        ++$nchild;
        $s =
"update $clusterTable set n_child=$nchild where ci=$ci_anc and ti_root=$ti_anc and cl_type=\'subtree\'";
        print "$count parent cluster updates done\n"
          if ( $count / 10000 == int( $count / 10000 ) );
        $count++;
        $dbh->do($s);
    }
    $shs->finish;
}
$sh->finish;
$count = 0;
print "Updating node table with cluster numbers...\n";
update( "n_clust_node",
"select ti_root,count(*) as n from $clusterTable where cl_type='node' group by ti_root"
);
update( "n_clust_sub",
"select ti_root,count(*) as n from $clusterTable where cl_type='subtree' group by ti_root"
);
update( "n_PIclust_sub",
"select ti_root,count(*) as n from $clusterTable where cl_type='subtree' and PI=1 group by ti_root"
);
#####################
sub update {
    my ( $field, $sql ) = @_;
    $sh = $dbh->prepare($sql);
    $sh->execute;
    while ( $H = $sh->fetchrow_hashref ) {
        $ti = $H->{ti_root};
        $n  = $H->{n};
        $s  = "update $nodeTable set $field=$n where ti=$ti";
        print "$count updates done\n"
          if ( $count / 10000 == int( $count / 10000 ) );
        $count++;
        $dbh->do($s);
    }
}
