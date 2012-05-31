#!/usr/bin/perl -w

## CAREFUL: I've added two fields, but these are not in the nodes table file!!!

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
#$nodeTable="nodes_test";

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
                n_otu_desc INT UNSIGNED,   
		ti_genus INT UNSIGNED,
		n_genera INT UNSIGNED
                ) ";



$dbh->do("$sql");

# The local keyword seems to be important for some mysql configs.
#$sql= "load data local infile \'$filename\' into table $nodeTable (ti , ti_anc , terminal_flag , rank_flag , model , taxon_name, common_name , rank , n_gi_node , n_gi_sub_nonmodel , n_gi_sub_model , n_clust_node , n_clust_sub , n_PIclust_sub , n_sp_desc , n_sp_model , n_leaf_desc , n_otu_desc ) fields terminated by '\\t' enclosed by 'z'"; 
$sql= "load data local infile \'$filename\' into table $nodeTable fields optionally enclosed by '\\''"; 
# Note: this list is two variables short of the create command above, because currently when I write the data files, I DO NOT write the
# ti_genus and n_genera data into the nodes_xxx table.

#print "$sql\n";
$dbh->do("$sql");

