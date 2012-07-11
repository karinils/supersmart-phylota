#!/usr/bin/perl
# USAGE: pb_put_trees.pl -c configFile -t treeFile
# Read a file with tree descriptions and insert into phylota db along with CFI
# Format of treefile:
# filename|tree description
# The filename should have a string imbedded that allows for extraction of the node and cluster ids
# such as ...ti###_cl#### (look for the regex below).
use File::Spec;
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl eq '-c' ) { $configFile = $par; }
    if ( $fl eq '-f' ) { $treeFile   = $par; }
}
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$clusterTable = "clusters_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$treeField = "clustalw_tree";
$resField  = "clustalw_res";
guts();

sub guts {
    open FH, "<$treeFile" or die "Tree file not found\n";
    while (<FH>) {
        ( $fn, $Tree ) = split '\|';
        ( $ti, $cl ) = ( $fn =~ /ti(\d+)_cl(\d+)/ );
        if ( ($Tree) = /tree\s+PAUP\_\d+\s*=\s*(?:\[.+\])*\s*(.*);/i ) {
            $Tree =~ s/gi(\d+)\_ti\d+/$1/g;
            $n_internal = @lparens = ( $Tree =~ m/(\()/g );
            @taxa = ( $Tree =~ m/(\,)/g );
            $n_terminal = @taxa + 1;
            $cfi =
              ( $n_internal - 1 ) / ( $n_terminal - 3 )
              ; # this is the right CFI for an unrooted tree in PAUP with a basal tric

            #			print "The edited tree for ti=$ti cl=$cl is $Tree\n";
            #			print "CFI=$cfi\n";
            $s =
"update $clusterTable set $treeField=\'$Tree\',$resField=$cfi where ti_root=$ti and ci=$cl and cl_type='subtree'";

            #			print "$s\n";
            $dbh->do($s);
        }

        #		die if (++$count>10);
    }
    close FH;
}
