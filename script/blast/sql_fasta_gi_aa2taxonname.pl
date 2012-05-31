#!/usr/bin/perl
# Script to format and display a tree from the database as a nexus file.
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
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
    if (/^[>]*(gi|gi\||)(\d+)(.*)/)    #either gi|XX ... giXX .. or XX
    {
        ( $ti, $name, $formatted_label ) = lookup($2);
        print ">$formatted_label\n";
    }
    else { print }
}

sub lookup {
    my ( $gi_aa, $outFormat ) = @_;
    $sqls =
"select $nodeTable.ti,taxon_name from $nodeTable,seqs,aas where $nodeTable.ti=seqs.ti and seqs.gi=aas.gi and gi_aa=$gi_aa";
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    my ( $ti, $name ) = $shs->fetchrow_array;
    $name =~ s/\'//g;    # hack to fix single quotes in cur db

    #	$name =~ s/\s/\_/g; # replace whitespace with underscore
    $shs->finish;
    my $formatted_label = "\'$name\_gi$gi_aa\_ti$ti\'";
    return ( $ti, $name, $formatted_label );
}
