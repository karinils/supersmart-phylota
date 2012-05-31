#!/usr/bin/perl -w
# Assuming a bunch of clades have already been imported into the nodes_XX table, but that deeper
# nodes in the NCBI tree have not yet been added, this script visits the root of each of those clades
# gathers the relevant info and then recurses deeper into the tree toward the root, summing up counts
# of sequences and taxa (but not clusters!) and depositing them at appropriate nodes in the table.
# This script can be run before the model organism script is run because it only deals with seqs and taxa,
# which are not updated in any way by the model org script.
$tiStart = 2759;    # Eukaryotes
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ )  { $configFile = $par; }
    if ( $fl =~ /-ti/ ) { $tiStart    = $par; }
}
die if ( !($configFile) );
%pbH     = %{ pb::parseConfig($configFile) };
$release = pb::currentGBRelease();

# ************************************************************
# Table names with proper release numbers
$nodeTable = "nodes" . "\_$release";

# ************************************************************
# mysql initializations
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );

# ************************************************************
# Read the NCBI names, nodes files...
$namesFile = "$pbH{GB_TAXONOMY_DIR}/names.dmp";
$nodesFile = "$pbH{GB_TAXONOMY_DIR}/nodes.dmp";
open FH, "<$namesFile";
while (<FH>) {
    ( $taxid, $name, $unique, $nameClass ) = split '\t\|\t';
    if ( $nameClass =~ /scientific name/ ) { $sciNameH{$taxid} = $name; }
}
close FH;
open FH, "<$nodesFile";
while (<FH>) {
    ( $taxid, $ancid, $rank, @fields ) = split '\t\|\t';
    $ancH{$taxid}  = $ancid;
    $rankH{$taxid} = $rank;
    if ( !exists $nodeH{$ancid} ) { $nodeH{$ancid} = nodeNew($ancid); }
    if ( !exists $nodeH{$taxid} )    # both these exist tests must be present!
    {
        $nodeH{$taxid} = nodeNew($taxid);
    }
    addChild( $nodeH{$ancid}, $nodeH{$taxid} );
}
close FH;

# Start the recursion at this node
$rootRef = $nodeH{$tiStart};
recurseSum($rootRef);

# **********************************************************
# **********************************************************
sub nodeNew {
    my ($id) = @_;
    return {
        ID                      => $id,
        DESC                    => [],
        NUMSEQ                  => 0,
        NUMDESCSEQ              => 0,
        NUMDESCSEQNONMODEL      => 0,
        NUMDESCSPECIES          => 0,
        NUMDESCSEQNODES         => 0,
        NUMDESCSEQNODESNONMODEL => 0,
        NUMSEQTOTAL             => 0,
        NUMSEQTOTALNONMODEL     => 0
    };
}

# **********************************************************
sub addChild {
    my ( $nodeRef, $childRef ) = @_;
    push @{ ${$nodeRef}{DESC} }, $childRef;
}

# **********************************************************
sub recurseSum {
    my ($nodeRef) = @_;
    my ( $n_node_desc, @descRefs, $numDesc, $i, $ti, $descRef );
    $ti = $nodeRef->{ID};
    if ( $rankH{$ti} eq "genus" ) {
        return 1;
    }
    else {
        $numDesc = scalar @{ $nodeRef->{DESC} };
        my ($genusSum) = 0;
        for $i ( 0 .. $numDesc - 1 ) {
            $descRef = ${ $nodeRef->{DESC} }[$i];
            $genusSum += recurseSum($descRef);
        }

        #print "$sciNameH{$ti}\t$genusSum\n";
        my $s = "UPDATE $nodeTable set n_genera=$genusSum where ti=$ti";
        print "$s\n";
        $dbh->do("$s");
        return ($genusSum);
    }
}
