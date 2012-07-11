#!/usr/bin/perl
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
    if ( $fl =~ /-f/ ) { $giFile     = $par; }
}
die if ( !($configFile) );
%pbH     = %{ pb::parseConfig($configFile) };
$release = pb::currentGBRelease();

# ************************************************************
$seqTable  = "features";
$nodeTable = "nodes_$release";

# ************************************************************
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
open FH, "<$giFile";
while (<FH>) {
    chomp;
    $gi_target = $_;
    $sql =
"select taxon_name,gi,gi_feat,primary_tag,$nodeTable.ti,seq from $seqTable,$nodeTable where $nodeTable.ti=$seqTable.ti and gi=$gi_target";

    #print "$sql\n";
    $sh = $dbh->prepare($sql);
    $sh->execute;
    if ( ( $name, $gi, $gi_feat, $primary_tag, $ti, $seq ) = $sh->fetchrow_array
      )    # only returns one row (presumably) here and next...
    {
        print ">$name\_cds_gi$gi\_ti$ti\n$seq\n";
    }
    $sh->finish;
}
close FH;
