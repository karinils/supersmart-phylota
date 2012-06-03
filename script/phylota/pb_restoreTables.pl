# this is a legacy script file from phylota
#!/usr/bin/perl
use strict;
use warnings;
use Bio::Phylo::PhyLoTA::DBH;
use Bio::Phylo::PhyLoTA::Config;

my $config  = Bio::Phylo::PhyLoTA::Config->new;
my $release = $config->currentGBRelease;
my $dbh = Bio::Phylo::PhyLoTA::DBH->new;

$dbh->do ("drop table if exists nodes_$release"); 
$dbh->do ("drop table if exists clusters_$release"); 
$dbh->do ("drop table if exists ci_gi_$release"); 

$dbh->do ("create table nodes_$release like nodes_$release\_bak");
$dbh->do ("create table clusters_$release like clusters_$release\_bak");
$dbh->do ("create table ci_gi_$release like ci_gi_$release\_bak");

$dbh->do ("insert nodes_$release select * from nodes_$release\_bak");
$dbh->do ("insert clusters_$release select * from clusters_$release\_bak");
$dbh->do ("insert ci_gi_$release select * from ci_gi_$release\_bak");