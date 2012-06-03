# this is a legacy script file from phylota
#!/usr/bin/perl
# WARNING! REMOVES EXISTING BACKUPS!
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::PhyLoTA::DBH;

# process command line arguments
my ( $release, $verify );
GetOptions(
	'release=s' => \$release,
	'verify=s'  => \$verify,
);

die "must verify to run this: look at the code, stupid" if !$verify  || $verify ne "yes";
die "must specify release number" if !$release;

my $dbh = Bio::Phylo::PhyLoTA::DBH->new;

# drop existing backup tables
$dbh->do ("drop table if exists nodes_$release\_bak"); 
$dbh->do ("drop table if exists clusters_$release\_bak"); 
$dbh->do ("drop table if exists ci_gi_$release\_bak"); 

# create new backup tables
$dbh->do ("create table nodes_$release\_bak like nodes_$release");
$dbh->do ("create table clusters_$release\_bak like clusters_$release");
$dbh->do ("create table ci_gi_$release\_bak like ci_gi_$release");

# make backup into newly created tables
$dbh->do ("insert nodes_$release\_bak select * from nodes_$release");
$dbh->do ("insert clusters_$release\_bak select * from clusters_$release");
$dbh->do ("insert ci_gi_$release\_bak select * from ci_gi_$release");
