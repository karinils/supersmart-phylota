#!/usr/bin/perl
## UNFINISHED...SHOULD INCLUDE EVERYTHING IN A GENUS IF *ANY* QUERIED MEMBER OF A GENUS IS MISSING (EVEN
## IF OTHER QUERIED MEMBERS ARE PRESENT). THIS JUST REQUIRES CHECKING A HASH TO NOT DUPLICATE ONES ALREADY LISTED...
# Converts taxon names to NCBI taxon IDs (or vice versa). Input file is a list of names or integers, one per row
# Must use the appropriate PB config file
# If $VAR_STRIP == 1, then any time a trinomial fails to match, we strip anything like "...var. XXX" from the
# name and search for the binomial. This might possibly return multiple entries with the same id.
$VAR_STRIP = 1;
use DBI;
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
    if ( $fl =~ /-f/ ) { $nameFile   = $par; }
    if ( $fl =~ /-o/ ) { $outFile    = $par; }
}
open FHo, ">$outFile" or die "Problem opening out file $outFile\n";
$searchString = "[Cc]yt[ochrome]*[ ]*[Bb]";

#$searchString = "[Cc][yt]*[ochrome]*[ ]*[Oo][Xx][idase]*";
#$searchString = "COX";
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$database     = $release;
$tablename    = "nodes_$release";
$clusterTable = "clusters\_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
open FH, "<$nameFile";

while (<FH>) {
    chomp;
    $qname = $_;
    $lsave = $_;
###
    #	($c1,$qname)=split;
    $qname =~ s/\_/ /g;
###
    if ( $qname =~ /\b\d+\b/ ) {
        $tiSearch = 1;
    }
    else {
        $tiSearch = 0;

# note the order of the following is important, because the get passes trailing spaces as
# +'s, which we then replace with spaces and have to delete those...
        $qname =~
          s/\+/ /g;    # case of spaces in the query, which are passed as '+'
        $qname =~ s/^\s+//;
        $qname =~ s/\s+$//;
        $qname =~
          s/\*/%/g # convert this wildcard symbol to the mysql symbol for its query;
    }

    # *****  FIRST, CHECK FOR AN EXACT MATCH WITH TAXON NAME ****
    if ($tiSearch) {
        $sql =
"select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where ti=$qname";
    }
    else {

# Following OR is a hack -- we need to fix the imbedded single quotes. Currently some tax names are not consistent about this
        $sql =
"select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where (taxon_name LIKE \"\'$qname\'\" or taxon_name LIKE \"$qname\") order by taxon_name";
    }

    #print "$sql\n";
    $sh = $dbh->prepare($sql);
    $sh->execute;
    $qname =~ s/%/\*/g;    # just in case using * as the wildcard; mysql likes %
    $rowCount = 0;
    print "$lsave:\t";
    while ( $rowHRef = $sh->fetchrow_hashref
      )                    # only returns one row (presumably) here and next...
    {
        ++$rowCount;
        $tn = $rowHRef->{taxon_name};
        $ti = $rowHRef->{ti};
        ( $clustCount, $tn, $longestSeq ) = clusterSearch( $ti, $searchString );
        if ( $clustCount > 0 ) {
            $nameH{$ti}      = $tn;
            $seqH{$ti}       = $longestSeq;
            $seqStatusH{$ti} = "Exact";
            print "NAME AND CLUSTER FOUND\n";
        }
        else               # exact name match, but this name has no cluster
        {
            $numCong = genusLookup($lsave);
            if ($atLeastOneMatch) {
                print
"NAME FOUND (WITH NO CLUSTER) AND CONGENER CLUSTER FOUND (#congeners = $numCong)\n";
                ++$numTaxaHittingCongener;
            }
            else {
                print
"NAME FOUND (WITH NO CLUSTER) AND NO CONGENER CLUSTER FOUND\n";
            }
        }
    }
    $sh->finish;
    die "Dying a homonym death\n" if ( $rowCount > 1 );

    # *****  BUT, if no exact matches found, examine possible congeners
    if ( $rowCount == 0 ) {
        if ($VAR_STRIP) { checkVarieties() }
        $numCong = genusLookup($lsave);
        if ($atLeastOneMatch) {
            print
"NAME NOT FOUND BUT CONGENER CLUSTER FOUND (#congeners = $numCong)\n";
            ++$numTaxaHittingCongener;
        }
        else {
            print "NAME NOT FOUND AND CONGENER CLUSTER NOT FOUND\n";
        }
    }
}    # end FH read
$numNoCongeners   = @noCongenerClusterList;
$numExactMatch    = keys %exactMatchAndClusterPresentH_tn;
$numCongenerMatch = keys %congenerMatchAndClusterPresentH_tn;
print
  "Num input taxa with exact match to name having a cluster: $numExactMatch\n";
print
"Num input taxa with match to at least one congener having a cluster: $numTaxaHittingCongener\n";
print "$Number of taxa with no congeners = $numNoCongeners\n";
print "[ @noCongenerClusterList ]\n";

#replaceTrinomial(\%seqH);
writeFasta( \%seqH );
#######################################
sub checkVarieties() {
    if ( $qname =~ /var\./ ) {
        $qname =~ s/\s+var\.(.)+$//;
        print "Checking alternative name ... $qname\n";
        $rowCount = 0;
        $sql =
"select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where (taxon_name LIKE \"\'$qname\'\" or taxon_name LIKE \"$qname\") order by taxon_name";
        $sh = $dbh->prepare($sql);
        $sh->execute;
        while ( $rowHRef = $sh->fetchrow_hashref ) {
            ++$rowCount;
            $tn = $rowHRef->{taxon_name};
            $ti = $rowHRef->{ti};
            if ( $tiSearch == 1 ) {
                print "$tn\n";
            }
            else {
                print "$tn\t$ti\n";
            }
        }
        $sh->finish;
        if ( $rowCount == 0 ) { print "$qname still not found...skipping\n"; }
    }
}

#****************************************************************************************************
#****************************************************************************************************
sub replaceTrinomial

  # if a binomial is present for some trinomial, remove the trinomial
{
    my ($href) = @_;
    my $name;
    my %h = %{$href};
    for $ti ( keys %h ) {
        $t = $nameH{$ti};
        ($name) = ( $t =~ /(.*)_gi\d+/ );
        $nH{$name} = 1;
    }
    for $ti ( keys %h ) {
        $t = $nameH{$ti};
        ($name) = ( $t =~ /(.*)_gi\d+/ );
        if ( $name =~ /(\w+_\w+)_\w+/ )    # trinomial
        {
            if ( $nH{$1} ) {
                print
"Matching binomial $1 found for trinomial $name (Removing it!)\n";
                delete $seqH{$ti};
            }
            else { print "No matching binomial $1 found for trinomial $name\n" }
        }
    }
}

#****************************************************************************************************
sub writeFasta {
    my ($href) = @_;
    my %h = %{$href};
    my @sorted = sort { $nameH{$a} cmp $nameH{$b} } keys %h;
    for (@sorted) {
        print FHo ">$nameH{$_} [$seqStatusH{$_}]\n$h{$_}\n";
    }
}

#****************************************************************************************************
sub genusLookup

# Input: A taxon name and TI for a taxon that is NOT found in our database.
# Builds a list of all congeners in the genus containing $thisTI that also have a cluster matching $searchString
# These are either taxa that correspond to some exact match in another query, OR
# they are congeners. Just do the bookkeeping to track these. Adds these to the global hashes.
{
    my ($qname) = @_;
    my ($genus) = ( $qname =~ /^([A-Z][a-z]+)/ );
    my $sql =
"select rank,taxon_name,ti from $tablename where taxon_name LIKE \"$genus%\" order by taxon_name";
    my $sh = $dbh->prepare($sql);
    $sh->execute;
    my $numCongeners = 0;
    $atLeastOneMatch = 0;
    while ( $rowHRef =
        $sh->fetchrow_hashref )    # loop over all leaves of this genus
    {
        $rank = $rowHRef->{rank};
        next if ( $rank eq "genus" );
        $tn = $rowHRef->{taxon_name};
        $ti = $rowHRef->{ti};

        #				print "Genus $genus\tCongener: $tn (ti$ti)\n";
        if ( $seqH{$ti} ) {
            ++$numCongeners;
            $atLeastOneMatch = 1;
            next;
        }    # needn't consider this further; it's already been seen
        ( $clustCount, $tn, $longestSeq ) = clusterSearch( $ti, $searchString );
        if ( $clustCount > 0 ) {
            $nameH{$ti}      = $tn;
            $seqH{$ti}       = $longestSeq;
            $seqStatusH{$ti} = "Con";
            $atLeastOneMatch = 1;
            ++$numCongeners;
        }
    }
    if ( $atLeastOneMatch == 0 ) { push @noCongenerClusterList, $qname }

    #print "***** $atLeastOneMatch   $numCongeners\n";
    return $numCongeners;
}

#****************************************************************************************************
sub clusterSearch {
    my ( $ti, $searchString ) = @_;

    # following gets the longest sequence that matches search criterion!
    my $sql =
"select taxon_name,length,gi,seq,ci,cl_type, def from $tablename,$clusterTable,seqs where seqs.ti=$tablename.ti and ti_root=$ti and seed_gi=gi and cl_type='node' and def REGEXP \"$searchString\" order by length desc limit 1";
    my $rowCount;
    my $sh = $dbh->prepare($sql);
    $sh->execute;
    while ( $rowHRef = $sh->fetchrow_hashref ) {
        ++$rowCount;
        $taxon_name = $rowHRef->{taxon_name};
        $taxon_name =~ s/\s/\_/g;
        $ci      = $rowHRef->{ci};
        $gi      = $rowHRef->{gi};
        $seq     = $rowHRef->{seq};
        $cl_type = $rowHRef->{cl_type};
        $def     = $rowHRef->{def};

        #print "\t$ti\t$ci\t$cl_type\t$def\n";
        $tn = "$taxon_name\_gi$gi\_ti$ti";
    }
    return ( $rowCount, $tn, $seq );
}
