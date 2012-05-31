#!/opt/rocks/bin/perl
### CODE ALL MUCKED UP REGARDING OUTPUT FORMATS AND AA vs. DNA...WATHC OUT
# Read a fasta file that has giXXX in the def line, lookup ti and name and possibly sort and filter using a list of gis
# I am now using the convention that dna has 'giXXX' and aa has 'gi_aaXXX'. This refers only to which database at NCBI to find these seqs!
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;
use Bio::SeqIO;
$gisAA = 0;    # default treat gi# as referring to nuc database
while ( $fl = shift @ARGV ) {
    if ( $fl eq '-c' )    { $configFile = shift @ARGV; }
    if ( $fl eq '-f' )    { $faFile     = shift @ARGV; }
    if ( $fl eq '-sort' ) { $sortKey    = shift @ARGV; }    #"gi or ti or name"
    if ( $fl eq '-filter' ) {
        $filterFile = shift @ARGV;
    }    # keep only gis listed in this file
    if ( $fl eq '-tax_labels' ) {
        $taxLabelsOption = shift @ARGV;
    }    # gi,giti,ti,name,all
    if ( $fl eq '-gis_are_aa' ) { $gisAA = 1; }

#  if ($fl eq '-filter_ti') {$filterFileTI = shift @ARGV;} # keep all sequences with tis listed in this file
#			# for this, we expect gi_ti format in regex. NB. Will pluck only one seq per ti! (if more, this is unpredictable).
}

# Initialize a bunch of locations, etc.
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$database     = $release;
$clusterTable = "clusters_$release";
$seqTable     = "seqs";
$nodeTable    = "nodes_$release";
if ($filterFile) {
    open FH, "<$filterFile";
    while (<FH>) {
        if (/(gi|gi_aa)(\d+)/) { $giFilterH{$2} = 1 }
    }
}
close FH;
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$seqio_obj = Bio::SeqIO->new( -file => $faFile, -format => "fasta" );
while ( $seq_obj = $seqio_obj->next_seq ) {
    $def = $seq_obj->display_id . " "
      . $seq_obj->desc;    # this is how Bioperl makes a definition line!

    #print "$def ... \n";
    $seq = $seq_obj->seq;
    if ( ( $gi_type, $gi ) = ( $def =~ /(gi|gi_aa)(\d+)/ ) ) {
        next if ( $filterFile && ( !( exists $giFilterH{$gi} ) ) );
        $gi_type = 'gi_aa';
        ( $ti, $name, $formatted_label ) = lookup( $gisAA, $gi );
        $ti_of_gi_H{$gi}    = $ti;
        $taxon_of_gi_H{$gi} = $name;
        $seqH{$gi}          = $seq;
    }
    else  # some def lines might not contain a gi --> just store and print later
    {
        $nonstandardDef{$def} = $seq;
    }
}
@gis        = keys %seqH;
@sorted_gis = @gis;         # default order unsorted
if ( $sortKey eq 'name' ) {
    @sorted_gis = sort { $taxon_of_gi_H{$a} cmp $taxon_of_gi_H{$b} } @gis;
}
if ( $sortKey eq 'ti' ) {
    @sorted_gis = sort { $ti_of_gi_H{$a} <=> $ti_of_gi_H{$b} } @gis;
}
if ( $sortKey eq 'gi' ) {
    @sorted_gis = sort { $a <=> $b } @gis;
}
for $gi (@sorted_gis) {
    $label = form_taxon_name( $gi, $taxLabelsOption );
    print ">$label\n$seqH{$gi}\n";
}
for $def ( sort keys %nonstandardDef ) {
    print ">'$def'\n$nonstandardDef{$def}\n";
}

sub lookup {
    my ( $gi_type, $gi, $outFormat ) = @_;
    if ( $gi_type == 1 ) {
        $sqls =
"select $nodeTable.ti,taxon_name from $nodeTable,seqs,aas where $nodeTable.ti=seqs.ti and seqs.gi=aas.gi and gi_aa=$gi";
    }
    else {
        $sqls =
"select $nodeTable.ti,taxon_name from $nodeTable,seqs where $nodeTable.ti=seqs.ti  and gi=$gi";
    }

    #print "$sqls\n";
    #die;
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    my ( $ti, $name ) = $shs->fetchrow_array;
    $name =~ s/\'//g;      # hack to fix single quotes in cur db
    $name =~ s/\s/\_/g;    # replace whitespace with underscore
    $shs->finish;

    #	my $formatted_label = "\'$name\_$gi_type$gi\_ti$ti\'";
    my $formatted_label = "$name\_$gi\_ti$ti";
    return ( $ti, $name, $formatted_label );
}

sub form_taxon_name {
    my ( $gi, $option ) = @_;
    my ( $t, $name );
    if ( $option eq 'gi' )   { return "gi$gi" }
    if ( $option eq 'giti' ) { return "gi$gi\_ti$ti_of_gi_H{$gi}" }
    if ( $option eq 'name' ) { return "$taxon_of_gi_H{$gi}" }
    if ( $option eq 'all' ) {
        $name = $taxon_of_gi_H{$gi};
        $name =~ s/\'//g;

        #$t="\'gi$gi\_ti$ti_of_gi_H{$gi} $name\'";
        $t = "$name\_gi$gi\_ti$ti_of_gi_H{$gi}";
        return $t;
    }
}
