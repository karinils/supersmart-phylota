#!/usr/bin/perl
# Based on the NCBI nodes table and the seqs stored already in our PB seq table, find a set of mutually
# exclusive clades to partition the leaf taxa of the tree. The root node of each clade should have the
# following property: the total number of seqs in the clade is <= cutoffMagicGI, but the total of its parent
# should be > that value. One caveat. Any node with > cutoffModelGI seqs does not have its sequences counted
# in this calculation. Approximately this accounts for the model orgs that will be ignored by the crawl scripts
# --but only approximately, as those scripts actually do clustering to determine if its a model...
# Wow. Apparently in any release, there are some sequences that are in the seq table, but which
# correspond to none of the tis in the NCBI tree. This means there are fewer total gis in the PB tree
# than are in the PB database proper. In release 172, this was around 7000! Must reflect taxonomy changes...?
# Finally, let's exclude any putative magic node that has 'environment' in its scientific names. The
# ENV sequences are not read into the seq or features table presently, so they always end up with 0 seqs.
use DBI;
use pb;
$tiStart = 2759;    # Eukaryotes
while ( my $fl = shift @ARGV ) {
    my $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
}
if ( !( -e $configFile ) ) { die "Missing config file pb.conf\n"; }
my %pbH     = %{ pb::parseConfig($configFile) };
my $release = pb::currentGBRelease();
die "Couldn't find GB release number\n" if ( !defined $release );

# ***********************
my $cutoffModelGI = 1000
  ; # Do not tally a node if it has more than this number of seqs; it's probably a model
my $cutoffMagicGI =
  50000;    # Stop at the first node that exceeds this number of seqs
my $maxUnclassifiedChildren = 100
  ; # Ignore /unclassified/ nodes that have huge numbers of children; these are barcodes!

# ***********************
# Set up a hash that has the number of gis per ti
my $seqTable = "seqs";
my $dbh      = db_connect();
my $sql      = "select ti,count(*) as ngi from seqs group by ti";
my $sh       = $dbh->prepare($sql);
$sh->execute;
while ( $H = $sh->fetchrow_hashref ) {
    $ngiH{ $H->{ti} } = $H->{ngi};
    $seqTotal0 += $H->{ngi};
}

#print "Read seq table...\n";
# ************************************************************
# Read the NCBI names, nodes files...
my ( %sciNameH, %commonNameH );
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/names.dmp";
while (<FH>) {
    my ( $taxid, $name, $unique, $nameClass ) = split '\t\|\t';
    if ( $nameClass =~ /scientific name/ )     { $sciNameH{$taxid}    = $name; }
    if ( $nameClass =~ /genbank common name/ ) { $commonNameH{$taxid} = $name; }
}
close FH;
my ( %ancH, %nodeH, %rankH );
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/nodes.dmp";
while (<FH>) {
    my ( $taxid, $ancid, $rank, @fields ) = split '\t\|\t';
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

#print "Read nodes/names tables from directory $pbH{'GB_TAXONOMY_DIR'}...\n";
#print "Recursing tree first time...\n";
# Start the recursion at this node
my $rootRef = $nodeH{$tiStart};
crawlTree($rootRef);                 # discard return values

#print "Recursing tree second  time...\n";
crawlTreeAgain($rootRef);            # discard return values

#print "Total magic nodes: $count\n";
#print "Total sequences in database: $seqTotal0\n";
#print "Total sequences among magic subtrees: $seqTotal1\n";
#print "Total sequences initialized: $seqTotal2\n";
# **********************************************************
sub crawlTree    # finds the number of sequences in each subtree (sort of)
{
    my ($nodeRef) = @_;
    die "Invalid or missing node reference passed to crawlTree\n"
      if ( !defined $nodeRef );
    my ( $ti, $descRef );

    # ...take care of this NODE
    $ti = $nodeRef->{ID};
    my ($ngi)      = 0;
    my ($ngiTotal) = 0;
    if ( exists $ngiH{$ti} ) {
        $ngi      = $ngiH{$ti};
        $ngiTotal = $ngiH{$ti};
        if ( $ngi > $cutoffModelGI ) {
            $ngi = 0
              ; # this is a "model" node by this criterion; don't add it to tally
        }
        $seqTotal2 += $ngiH{$ti};
    }
    for $descRef ( @{ $nodeRef->{DESC} } ) {
        my ( $n1, $n2 ) = crawlTree($descRef);
        $ngi      += $n1;
        $ngiTotal += $n2;
    }
    $nodeRef->{NUMSEQ}      = $ngi;
    $nodeRef->{NUMSEQTOTAL} = $ngiTotal;
    return ( $ngi, $ngiTotal );
}

# **********************************************************
sub crawlTreeAgain {
    my ($nodeRef) = @_;
    die "Invalid or missing node reference passed to crawlTree\n"
      if ( !defined $nodeRef );
    my ( $ti, $descRef );
    $ti = $nodeRef->{ID};
    if ( $sciNameH{$ti} =~ /unclassified/i ) {
        my $numChildren = @{ $nodeRef->{DESC} };
        if ( $numChildren > $maxUnclassifiedChildren ) { return }
    }
    my ($ngi) = $nodeRef->{NUMSEQ};
    for $descRef ( @{ $nodeRef->{DESC} } ) {
        my ($ngiChild) = $descRef->{NUMSEQ};
        if ( $ngi > $cutoffMagicGI && $ngiChild <= $cutoffMagicGI ) {
            my ($tiChild) = $descRef->{ID};
            next if ( $sciNameH{$tiChild} =~ /environment/i );
            print "$tiChild\t$sciNameH{$tiChild}\t$ngiChild\n";
            ++$count;
            $seqTotal1 += $descRef->{NUMSEQTOTAL};
        }
        crawlTreeAgain($descRef);
    }
    return;
}

# **********************************************************
sub nodeNew {
    my ($id) = @_;
    return { ID => $id, DESC => [], NUMSEQ => 0, NUMSEQTOTAL => 0 };
}

# **********************************************************
sub addChild {
    my ( $nodeRef, $childRef ) = @_;
    push @{ ${$nodeRef}{DESC} }, $childRef;
}

# **********************************************************
sub db_connect {
    my $dbh = DBI->connect(
"DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",
        $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD}
    );
    if ( !defined $dbh )    # try once to reconnect
    {
        warn "My DBI connection failed: trying to reconnect once\n";
        $dbh = DBI->connect(
"DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",
            $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD}
        );
    }
    die "My reconnection failed\n" if ( !defined $dbh );
    my $AutoReconnect = 1;
    $dbh->{mysql_auto_reconnect} = $AutoReconnect ? 1 : 0;
    return $dbh;
}
