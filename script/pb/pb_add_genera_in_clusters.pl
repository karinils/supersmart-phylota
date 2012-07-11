#!/usr/bin/perl -w
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
}
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$clusterTable = "clusters_$release";
$cigiTable    = "ci_gi_$release";
$nodeTable    = "nodes_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$sql = "select ti, ti_genus from $nodeTable";
$sh  = $dbh->prepare($sql);
$sh->execute;

while ( ( $ti, $ti_genus ) = $sh->fetchrow_array ) {
    $genus_of_tiH{$ti} = $ti_genus;
}
$sh->finish;
print "Done reading taxon names\n";
$sql = "select ti,clustid,cl_type,ti_of_gi from $cigiTable ";
$sh  = $dbh->prepare($sql);
$sh->execute;
while ( ( $ti, $clustid, $cl_type, $ti_of_gi ) = $sh->fetchrow_array ) {
    $ky    = "$ti\_$clustid\_$cl_type";
    $genus = $genus_of_tiH{$ti_of_gi};
    next
      if ( !$genus )
      ; # sometimes there is no genus for a sequence: e.g., undescribed taxon of uncertain rank
    $H{$ky}{$genus}++;
}
$sh->finish;
for $ky ( keys %H ) {
    $numGenera = scalar( keys %{ $H{$ky} } );

    #	print "$ky\t$numGenera\t";
    ( $ti, $clustid, $cl_type ) = ( $ky =~ /(\d+)\_(\d+)\_(.+)/ );
    $s =
"UPDATE $clusterTable set n_gen=$numGenera where ti_root=$ti and ci=$clustid and cl_type='$cl_type'";
    ++$numUpdates;
    $dbh->do($s);
}
print "$numUpdates done\n";
