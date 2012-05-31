#!/usr/bin/perl -w
use DBI;
$release = "168";

# ************************************************************
# mysql initializations
$database = "phylota";
$host     = "localhost";
$user     = "sanderm";
$passwd   = "phylota";     # password for the database
my $dbh =
  DBI->connect( "DBI:mysql:database=$database;host=$host", $user, $passwd );
$dbh->do("drop table if exists nodes_$release");
$dbh->do("drop table if exists clusters_$release");
$dbh->do("drop table if exists ci_gi_$release");
$dbh->do("create table nodes_$release like nodes_$release\_bak");
$dbh->do("create table clusters_$release like clusters_$release\_bak");
$dbh->do("create table ci_gi_$release like ci_gi_$release\_bak");
$dbh->do("insert nodes_$release select * from nodes_$release\_bak");
$dbh->do("insert clusters_$release select * from clusters_$release\_bak");
$dbh->do("insert ci_gi_$release select * from ci_gi_$release\_bak");
