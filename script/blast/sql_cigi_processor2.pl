#!/opt/rocks/bin/perl
# Note the above required to get the version that has bioperl libs
# Input: default is a two-column tab delim table with clusterid and taxon_label
# but if -single_cluster is set, then just a one column table with taxon_label
# Taxon label MUST have /gi(\d+)/ at the beginning of the label--before the first white space which is split on
# Filtering by min number of unambiguous sites is done first; then by excluded taxon name; only then is grouping
# by TI or genus done on the basis of max number of unambig sites. [all optionally of course]
use DBI;
use pb;
use File::Spec;
use Bio::Seq;
use Bio::SeqFeature::Generic;
use Bio::Factory::FTLocationFactory;
$seqType          = 'dna';    # default
$taxLabelsOption  = 'gi';
$minUnambigFilter = 0;
$exclude_sp       = 0;        # see below
$minunambig       = 0;

while ( $fl = shift @ARGV ) {
    if ( $fl eq '-c' ) { $configFile = shift @ARGV; }
    if ( $fl eq '-single_cluster' ) { $singleCluster = 1; }
    if ( $fl eq '-f' ) { $inFile = shift @ARGV; }    # cigi file
    if ( $fl eq '-d' ) {
        $inFileDir = shift @ARGV;
    } # directory where multiple files might live all having 'cigi' in their name!
    if ( $fl eq '-dna' ) { $seqType = 'dna'; }    # assumes dna for these gi ##
    if ( $fl eq '-aa' )  { $seqType = 'aa'; }
    if ( $fl eq '-aa_out' )  { $aaFile  = shift @ARGV; }    # fasta outfile
    if ( $fl eq '-dna_out' ) { $dnaFile = shift @ARGV; }    # fasta outfile
    if ( $fl eq '-tax_labels' ) {
        $taxLabelsOption = shift @ARGV;
    }    # gi,giti,ti,name,all
    if ( $fl eq '-minUnambig' ) {
        $minUnambigFilter = shift @ARGV;
    }    # keep only seqs >= this number of unambig sites
    if ( $fl eq '-exclude_sp' ) {
        $exclude_sp = 1;
    } # exclude taxon ids with species names containing ' sp. ' or ' x ' (hybrids)
    if ( $fl eq '-one_per_ti' ) {
        $one_per_ti = 1;
    }    # keep best one sequence per unique TI (has most unambig chars)
    if ( $fl eq '-one_per_genus' ) {
        $one_per_genus = 1;
    }    # keep best one sequence per unique genus (has most unambig chars)
    if ( $fl eq '-file_by_genus' ) {
        $file_by_genus = shift @ARGV;
    }    # print out separate files for each  genus (in each cluster)
    if ( $fl eq '-min_genera' ) {
        $min_genera = shift @ARGV;
    }    # skip file if fewer than min_genera
    if ( $fl eq '-min_TIs' ) {
        $min_TIs = shift @ARGV;
    }    # skip file if fewer than min_genera
    if ( $fl eq '-min_L' ) {
        $min_L = shift @ARGV;
    }    # skip file if shortest sequence is less than this
    if ( $fl eq '-print_taxa' ) { $print_taxa = 1; } # print table of taxon names
    if ( $fl eq '-overlap_file' ) {
        $overlap_file = shift @ARGV;
    }    # See how many TIs from this file are present in each cluster
    if ( $fl eq '-clusterfile_by_genus' ) {
        $clusterfile_by_genus = shift @ARGV;
    }    # print table of taxon names
    if ( $fl eq '-clusterfiles' ) {
        $clusterfiles = shift @ARGV;
    }    # write a separate fasta file for each cluster with this prefix
}

# Initialize a bunch of locations, etc.
die("Can't use both -d and -f options\n") if ( $inFile && $inFileDir );
if ($overlap_file) {
    open FH, "<$overlap_file";
    while (<FH>) {
        chomp;
        if ( ($ti_ov) = /ti(\d+)/ ) {
            $overlapH{$ti_ov} = 1;
        }
    }
    $numOV = keys %overlapH;

    #	print "Checking overlap on following $numOV taxon IDs\n";
    #	foreach (keys %overlapH) { print "$_\n"}
}
open FH, "<$inFile";
while (<FH>) {
    chomp;
    if ($singleCluster) {
        $cl    = 0;
        $label = $_;
    }
    else {
        ( $cl, $label ) = split;
    }

    #($gi) = ($label =~ /gi(\d+)/);
    $gi = $label;

    #print "$cl \t $gi\n";
    push @{ $cigi[$cl] }, $gi;
}
if ( $seqType eq 'dna' ) {
    $giField     = 'gi';
    $seqTable    = 'seqs';
    $seqField    = 'seq';
    $lengthField = 'length';
}
else {
    $giField     = 'gi_aa';
    $seqTable    = 'aas';
    $seqField    = 'seq_aa';
    $lengthField = 'length_aa';
}    # set the right query field
%pbH       = %{ pb::parseConfig($configFile) };
$release   = pb::currentGBRelease();
$database  = $release;
$nodeTable = "nodes_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$cl = -1;
for $clRef (@cigi) {
    my @gis = @{$clRef};
    $cl++;
    if ($clusterfiles) { open FHclfs, ">$clusterfiles.$cl"; }
    $minL = 1000000;
    $maxL = 0;
    undef %n_unambig_H;
    undef %taxon_nameH;
    undef %gis_of_ti_HoA;
    undef %ti_of_giH;
    undef %gis_per_tiH;
    undef %genusH;
    undef %gis_of_genus_ti_HoA;    # note this is local to each input cluster!
    undef %best_gi_of_tiH;
    undef %best_gi_of_ti_genusH;
    undef %genera_of_clusterH;
    $first   = 1;
    $countOV = 0;

    for $gi (@gis) {
        if ($first) {
            $repGI1 = $gi;         # keep a list of one gi per file
            $first  = 0;
        }
        $sqls =
"select ti, $seqField,$lengthField,def from $seqTable where $giField=$gi";
        $shs = $dbh->prepare($sqls);
        $shs->execute;
        ( $ti, $seq, $seqLi, $def ) = $shs->fetchrow_array;
        $seqH{$gi} = $seq;
        $n_unambigH{$gi} = numUnambig( $seq, $seqType );
        next if ( $n_unambigH{$gi} < $minUnambigFilter );
        $sqls = "select taxon_name,ti_genus from $nodeTable where ti=$ti";
        $shs  = $dbh->prepare($sqls);
        $shs->execute;
        ( $taxon_name, $ti_genus ) = $shs->fetchrow_array;
        $shs->finish;
        next if ( $exclude_sp && $taxon_name =~ /\ssp\.\s/ ); # contains ' sp. '
        next
          if ( $exclude_sp && $taxon_name =~ /\sx\s/i )
          ;    # contains ' x ' or ' X '; i.e. hybrids

        if ($clusterfiles) {
            print FHclfs ">$taxon_name\_gi$gi\_ti$ti  $def\n$seq\n";
        }
        $taxon_nameH{$ti} = $taxon_name;
        push @{ $gis_of_ti_HoA{$ti} }, $gi;
        $ti_of_giH{$gi} = $ti;
        $gis_per_tiH{$ti}++;
        $genusH{$ti_genus}             = 1;
        $genera_of_clusterH{$ti_genus} = 1;
        $cumul_genusH{$ti_genus}       = 1;
        push @{ $gis_of_genus_ti_HoA{$ti_genus} }, $gi;
        push @{ $gis_of_genus_ti_allHoA{$ti_genus} },
          $gi;    # this maintains a list for the whole data set

        #print "genus:$ti_genus:$gi\n";
        if ( $seqL < $minL ) { $minL = $seqL }
        if ( $seqL > $maxL ) { $maxL = $seqL }
        if ($overlap_file) {
            if ( exists $overlapH{$ti} ) { ++$countOV }
        }
    }
    push @all_genera, keys %genera_of_clusterH;
    @all_gis         = keys %ti_of_giH;
    $numGIs          = @all_gis;
    $numTIs          = keys %taxon_nameH;
    $numGenera       = keys %genusH;
    $cumul_numGenera = keys %cumul_genusH;
    next if ( $numGenera < $min_genera );
    next if ( $numTIs < $min_TIs );
    next if ( $minL < $min_L );
    ++$count;

    if ($overlap_file) {
        if ( $countOV >= 2 ) {
            ++$countClusters2Plus;
            $numOVTIsTotal += $numTIs;
        }
    }
    print
"$cl ($count): GIs:$numGIs\tTIs:$numTIs\tGenera:$numGenera (cumul:$cumul_numGenera)\tOV=$countOV\tMin Seq Length:$minL\tMax Seq Length:$maxL\tgi$repGI1\n";
    push @repGI,
      $repGI1;    # keep that one rep gi from the file if it passes the filter
    if ($print_taxa) {
        @sorted_names = sort values %taxon_nameH;
        for $name (@sorted_names) { print "$name\n" }
    }

    # Now do grouping by TI or genus as needed
    if ($one_per_ti) {
        foreach $ti ( keys %gis_of_ti_HoA ) {
            $maxUn = 0;
            for $gi ( @{ $gis_of_ti_HoA{$ti} } ) {
                if ( $n_unambigH{$gi} > $maxUn ) {
                    $maxUn  = $n_unambigH{$gi};
                    $bestGI = $gi;
                }
            }
            $best_gi_of_tiH{$ti} = $bestGI;
        }
        @all_gis = values %best_gi_of_tiH;
    }
    if ($one_per_genus) {
        foreach $ti_genus ( keys %gis_of_genus_ti_HoA ) {
            $maxUn = 0;
            for $gi ( @{ $gis_of_genus_ti_HoA{$ti_genus} } ) {
                if ( $n_unambigH{$gi} > $maxUn ) {
                    $maxUn  = $n_unambigH{$gi};
                    $bestGI = $gi;
                }
            }
            $best_gi_of_ti_genusH{$ti_genus} = $bestGI;
        }
        @all_gis = values %best_gi_of_ti_genusH;
    }
    if ($file_by_genus) {
        foreach $ti_genus ( keys %gis_of_genus_ti_HoA ) {
            $sqls = "select taxon_name from $nodeTable where ti=$ti_genus";
            $shs  = $dbh->prepare($sqls);
            $shs->execute;
            ($genus_name) = $shs->fetchrow_array;
            $shs->finish;
            $genus_name =~ s/'//g;
            open FHO, ">$file_by_genus.$cl.$genus_name.ti$ti_genus.fa";
            for $gi ( @{ $gis_of_genus_ti_HoA{$ti_genus} } ) {
                $def = form_taxon_name( $gi, $taxLabelsOption );
                print FHO ">$def\n$seqH{$gi}\n";
            }
            close FHO;
        }
    }
    if ( $aaFile && $seqType eq 'aa' ) {
        open FHO, ">$aaFile";
        for $gi (@all_gis) {
            $sqls = "select $seqField from $seqTable where $giField=$gi";
            $shs  = $dbh->prepare($sqls);
            $shs->execute;
            ($seq) = $shs->fetchrow_array;
            $def = form_taxon_name( $gi, $taxLabelsOption );
            print FHO ">$def\n$seq\n";
            $shs->finish;
        }
        close FHO;
    }
    if ($dnaFile) {
        open FHO, ">$dnaFile.$cl.fa";
        for $gi (@all_gis) {
            $def = form_taxon_name( $gi, $taxLabelsOption );
            print FHO ">$def\n$seqH{$gi}\n";
        }
        close FHO;
    }
    close FH;
}
if ($clusterfiles) { close FHclfs }
print
"Total number of clusters overlapping by at least 2 taxa: $countClusters2Plus\n";
print
  "Total number of TIs participating in these 2+ clusters: $numOVTIsTotal\n";
for $genus_ti (@all_genera) {
    $countGeneraCluster{$genus_ti}++;
}
for $ti_genus ( keys %countGeneraCluster ) {
    $count = $countGeneraCluster{$ti_genus};
    if ( $count > 1 ) {
        $sqls = "select taxon_name from $nodeTable where ti=$ti_genus";
        $shs  = $dbh->prepare($sqls);
        $shs->execute;
        ($genus_name) = $shs->fetchrow_array;
        $shs->finish;
        $genus_name =~ s/'//g;

        #print "$genus_name ($ti_genus)\t$count\n";
        ++$countSplitGenera;
        $genH{$genus_name} = $count;
    }
}
print "Number of split genera:$countSplitGenera\n";
@sortedGen = sort keys %genH;
foreach (@sortedGen) { print "$_\t$genH{$_}\n" }
if ($clusterfile_by_genus) {
    open FHcf, ">$clusterfile_by_genus" or die "bloops";
    $clusterID = 0;
    for $ti_genus ( keys %gis_of_genus_ti_allHoA ) {
        print "$ti_genus\n";
        for $gi ( @{ $gis_of_genus_ti_allHoA{$ti_genus} } ) {
            $def = form_taxon_name( $gi, $taxLabelsOption );
            print FHcf "$clusterID\t$def\n";
        }
        ++$clusterID;
    }
    close FHcf;
}
#######################
sub numUnambig {
    my ( $s, $type ) = @_;
    my $count = 0;
    $symbolsDNA = '[ACGT]';
    $symbolsAA  = '[ACDEFGHIKLMNPQRSTVWY]';
    if   ( $type eq 'aa' ) { $symbols = $symbolsAA }
    else                   { $symbols = $symbolsDNA }
    $count++ while $s =~ /$symbols/gi;    # case INSENSITIVE
    return $count;
}

sub form_taxon_name {
    my ( $gi, $option ) = @_;
    my ( $t, $name );
    if ( $option eq 'gi' )   { return "gi$gi" }
    if ( $option eq 'giti' ) { return "gi$gi\_ti$ti_of_giH{$gi}" }
    if ( $option eq 'all' ) {
        $name = $taxon_nameH{ $ti_of_giH{$gi} };
        $name =~ s/\'//g;
        $name =~ s/\s/\_/g;
        $t = "$name\_gi$gi\_ti$ti_of_giH{$gi}";
        return $t;
    }
}
