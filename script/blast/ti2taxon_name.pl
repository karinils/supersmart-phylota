#!/usr/bin/perl
# Script to format and display a tree from the database as a nexus file.
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    if ( $fl eq '-c' )   { $configFile = shift @ARGV; }
    if ( $fl eq '-col' ) { $column     = shift @ARGV; }
}

# Initialize a bunch of locations, etc.
%pbH       = %{ pb::parseConfig($configFile) };
$release   = pb::currentGBRelease();
$database  = $release;
$nodeTable = "nodes_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
while (<>) {
    @cols = split;
    $ti   = $cols[$column];
    {
        $name = lookup($ti);
        print "$ti\t$name\n";
    }
}

sub lookup {
    my ($ti) = @_;
    $sqls = "select taxon_name from $nodeTable where ti=$ti";
    $shs  = $dbh->prepare($sqls);
    $shs->execute;
    my ($name) = $shs->fetchrow_array;
    $name =~ s/\'//g;    # hack to fix single quotes in cur db
    $shs->finish;
    return ($name);
}
