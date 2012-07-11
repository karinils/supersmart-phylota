#!/usr/bin/perl -w
# Figures out which genus ti is the ancestor of a node. Adds this to node table, or NULL, if not found.
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
recurse($rootRef);

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
sub recurse {
    my ($nodeRef) = @_;
    my ( $n_node_desc, @descRefs, $numDesc, $i, $ti, $descRef );
    my ( $terminalNode, $rank, $anc, $rankFlag, $comName, $sciName, $rankName );
    $ti      = $nodeRef->{ID};
    $numDesc = scalar @{ $nodeRef->{DESC} };
    $rank    = $rankH{$ti};

 # following determines the six basic fields regarding the gi tallies for a node
    $anc      = $ancH{$ti};
    $sciName  = $dbh->quote( $sciNameH{$ti} );
    $rankName = $dbh->quote($rank);
    my ( $n_gi_node, $n_gi_sub_nonmodel, $n_gi_sub_model, $n_sp_desc,
        $n_leaf_desc, $n_otu_desc );
    for $i ( 0 .. $numDesc - 1 ) {
        $descRef = ${ $nodeRef->{DESC} }[$i];
        recurse($descRef);
    }
    $genusTI = findAncGenus($ti);
    if   ( defined $genusTI ) { $genusName = $sciNameH{$genusTI} }
    else                      { $genusName = NULL; $genusTI = 'NULL' }

    #print "$sciNameH{$ti}\t$genusName\n";
    my $s = "UPDATE $nodeTable set ti_genus=$genusTI where ti=$ti";

    #print "$s\n";
    $dbh->do("$s");
    return;
}

sub findAncGenus {
    my ($ti) = @_;
    my ( $rank, $anc );
    $anc = $ancH{$ti};
    while (1) {
        $rank = $rankH{$ti};
        if ( $rank eq "genus" ) { return $ti }
        if (   $rank eq "family"
            || $rank eq "order"
            || $rank eq "class"
            || $rank eq "phylum"
            || $rank eq "division"
            || $rank eq "kingdom" )
        {
            return undef;
        }
        if ( $ti == $tiStart ) { return undef }
        $ti = $ancH{$ti};
    }
    return undef;
}
