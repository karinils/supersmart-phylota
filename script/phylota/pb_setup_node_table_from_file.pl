#!/usr/bin/perl -w

#CAREFUL: OVERWRITES EXISTING TABLE
#USAGE: ... -c phylota_configuration_file -f clustertable_filename

# Timing: 9 sec on rel 165

use DBI;
use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  if ($fl =~ /-f/) {$filename = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

$nodeTable="nodes_$release";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$sql="drop table if exists $nodeTable";
$dbh->do("$sql");
$sql="create table if not exists $nodeTable(
                ti INT UNSIGNED primary key,
                ti_anc INT UNSIGNED, 
                INDEX(ti_anc), 
                terminal_flag BOOL, 
                rank_flag BOOL, 
                model BOOL,
                taxon_name VARCHAR(128),
                common_name VARCHAR(128),
                rank varchar(64),
                n_gi_node INT UNSIGNED, 
                n_gi_sub_nonmodel INT UNSIGNED,
                n_gi_sub_model INT UNSIGNED,
                n_clust_node INT UNSIGNED, 
                n_clust_sub INT UNSIGNED, 
                n_PIclust_sub INT UNSIGNED, 
                n_sp_desc INT UNSIGNED,
                n_sp_model INT UNSIGNED,
                n_leaf_desc INT UNSIGNED,
                n_otu_desc INT UNSIGNED   
                ) ";


$dbh->do("$sql");

# The local keyword seems to be important for some mysql configs.
$sql= "load data local infile \'$filename\' into table $nodeTable";
$dbh->do("$sql");

