#!/usr/bin/perl
# Script to format and display a tree from the database as a nexus file.
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    if ( $fl eq '-c' ) { $configFile = shift @ARGV; }
}

# Initialize a bunch of locations, etc.
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$database     = $release;
$clusterTable = "clusters_$release";
$seqTable     = "seqs";
$nodeTable    = "nodes_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );

while (<>) {
    s/gi(\d+)/lookup($1)/eg;    #matches giXX
    print;
}

sub lookup {
    my ($gi) = @_;
    $sqls =
"select $nodeTable.ti,taxon_name from $nodeTable,$seqTable where $nodeTable.ti=$seqTable.ti and gi=$gi";
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    my ( $ti, $name ) = $shs->fetchrow_array;
    $name =~ s/\'//g;           # hack to fix single quotes in cur db
    $name =~ s/\s/\_/g;         # hack to change space to underscore...
    $shs->finish;
    return ( $ti, $name );
}
