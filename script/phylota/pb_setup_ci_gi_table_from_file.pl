#!/usr/bin/perl -w

# CAREFUL! OVERWRITES EXISTING TABLE!

#USAGE: ... -c phylota_configuration_file -f clustertable_filename

# Timing: 9 sec on rel 165

use DBI;
use pb;
use Getopt::Long;
use strict;

# process command line arguments
my ( $configFile, $filename );
GetOptions(
	'config=s' => \$configFile,
	'file=s'   => \$filename,
);

# parse config file
my %pbH = %{ pb::parseConfig($configFile) };
my $release = pb::currentGBRelease();
my $ci_gi_table = "ci_gi_$release";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

# ti ... ti of the node at which this cluster was buildt
# clustid ... number on 0 .. n-1 for the cluster id
# cl_type
# gi ... the sequence id
# ti_of_gi ... the ti of that sequence

my $sql = "drop table if exists $ci_gi_table";
$dbh->do("$sql");

$sql = "create table if not exists $ci_gi_table(
	ti INT UNSIGNED,
	clustid INT UNSIGNED,
	cl_type ENUM('node','subtree'),
	gi BIGINT UNSIGNED,
	ti_of_gi INT UNSIGNED, 
	index(cl_type),
	index(cl_type),
	index(gi),
	index(ti,clustid,cl_type)
	)";
$dbh->do("$sql");

if ( $filename ) {
	# The local keyword seems to be important for some mysql configs.
	$sql= "load data local infile \'$filename\' into table $ci_gi_table";
	$dbh->do("$sql");
}

