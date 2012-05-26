#!/usr/bin/perl -w

# WARNING! REMOVES EXISTING BACKUPS!
use strict;
use Getopt::Long;
use DBI;

# ************************************************************
# mysql initializations 

my $database="phylota";
my $host="localhost";
my $user="sanderm";
my $passwd="phylota"; # password for the database

my ( $release, $verify );
GetOptions(
	'release=s' => \$release,
	'verify=s'  => \$verify,
	'user=s'    => \$user,
	'passwd=s'  => $passwd,
);

die ("must verify to run this: look at the code, stupid") if (!$verify  || $verify ne "yes");
die ("must specify release number") if (!$release);

my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",$user,$passwd);

$dbh->do ("drop table if exists nodes_$release\_bak"); 
$dbh->do ("drop table if exists clusters_$release\_bak"); 
$dbh->do ("drop table if exists ci_gi_$release\_bak"); 

$dbh->do ("create table nodes_$release\_bak like nodes_$release");
$dbh->do ("create table clusters_$release\_bak like clusters_$release");
$dbh->do ("create table ci_gi_$release\_bak like ci_gi_$release");

$dbh->do ("insert nodes_$release\_bak select * from nodes_$release");
$dbh->do ("insert clusters_$release\_bak select * from clusters_$release");
$dbh->do ("insert ci_gi_$release\_bak select * from ci_gi_$release");
