#!/usr/bin/perl
# Dumps a two column tab-delimited table of gis and tis based on the database
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
}
die if ( !($configFile) );
%pbH     = %{ pb::parseConfig($configFile) };
$release = pb::currentGBRelease();

# ************************************************************
$seqTable   = "seqs";
$nodesTable = "nodes_$release";
$fn         = "pb.dmp.ti_genus.$release";
die "Refusing to overwrite existing file $fn\n" if ( -e $fn );
open FH, ">$fn" or die;

# ************************************************************
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$sql = "select ti,taxon_name from $nodesTable where rank='genus'";
$sh  = $dbh->prepare($sql);
$sh->execute;
while ( $rowHRef =
    $sh->fetchrow_hashref ) # only returns one row (presumably) here and next...
{
    $ti_genus          = $rowHRef->{ti};
    $taxon_name        = $rowHRef->{taxon_name};
    $genusH{$ti_genus} = $taxon_name;
}
$sh->finish;
$sql = "select ti,ti_genus from $nodesTable where ti_genus IS NOT NULL ";
$sh  = $dbh->prepare($sql);
$sh->execute;
while ( $rowHRef =
    $sh->fetchrow_hashref ) # only returns one row (presumably) here and next...
{
    $ti       = $rowHRef->{ti};
    $ti_genus = $rowHRef->{ti_genus};
    print FH "$ti\t$genusH{$ti_genus}\n";
}
$sh->finish;
close FH;
