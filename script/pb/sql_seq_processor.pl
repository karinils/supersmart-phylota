#!/usr/bin/perl


# Now handles multiple input files, BUT I HAVE TO IMPLEMENT MULTIPLE OUTPUT FILES TO MATCH

# Input: A cigi file or gi file from blast search pipeline containing ONE cluster only (assumes this w/o checking)
# Output: Lots of stuff, including fasta files for the cluster and summary stats

# Filtering by min number of unambiguous sites is done first; then by excluded taxon name; only then is grouping
# by TI or genus done on the basis of max number of unambig sites. [all optionally of course]

# Can export trimmed dna cds sequences (-dna_out option). These are trimmed to begin and end on codon boundaries and
# exclude terminal stop codon.

use DBI;
use pb;

use File::Spec;
use Bio::Seq;
use Bio::SeqFeature::Generic;
use Bio::Factory::FTLocationFactory;


$seqType = 'dna'; # default
$taxLabelsOption= 'gi';
$minUnambigFilter = 0;
$exclude_sp = 0; # see below
$inFormat='gi';

$minunambig=0;

while ($fl = shift @ARGV)
  {
  if ($fl eq '-c') {$configFile = shift @ARGV;}
  if ($fl eq '-fmt') {$inFormat = shift @ARGV;}
  if ($fl eq '-f') {$inFile = shift @ARGV;} # cigi file
  if ($fl eq '-d') {$inFileDir = shift @ARGV;} # directory where multiple files might live all having 'cigi' in their name!
  if ($fl eq '-dna') {$seqType = 'dna';} # assumes dna for these gi ##
  if ($fl eq '-aa') {$seqType = 'aa';}
  if ($fl eq '-aa_out') {$aaFile = shift @ARGV;} # fasta outfile
  if ($fl eq '-dna_out') {$dnaFile = shift @ARGV;} # fasta outfile
  if ($fl eq '-tax_labels') {$taxLabelsOption = shift @ARGV;} # gi,giti,ti,name,all
  if ($fl eq '-minUnambig') {$minUnambigFilter = shift @ARGV;} # keep only seqs >= this number of unambig sites
  if ($fl eq '-exclude_sp') {$exclude_sp = 1;} # exclude taxon ids with species names containing ' sp. '
  if ($fl eq '-one_per_ti') {$one_per_ti = 1;} # keep best one sequence per unique TI (has most unambig chars)
  if ($fl eq '-one_per_genus') {$one_per_genus = 1;} # keep best one sequence per unique genus (has most unambig chars)
  if ($fl eq '-min_genera') {$min_genera = shift @ARGV} # skip file if fewer than min_genera
  if ($fl eq '-min_TIs') {$min_TIs = shift @ARGV} # skip file if fewer than min_genera
  if ($fl eq '-min_L') {$min_L = shift @ARGV} # skip file if shortest sequence is less than this
  if ($fl eq '-print_taxa') {$print_taxa = 1;} # print table of taxon names
  }
# Initialize a bunch of locations, etc.
die ("Can't use both -d and -f options\n") if ($inFile && $inFileDir); 

if ($inFileDir) # makes an array with the inFileNames, w/o paths...
	{
	opendir(DIR, $inFileDir);
	@inFiles=grep {/cigi/} readdir(DIR);
	}
if ($inFile)
	{
	($volume,$inFileDir,$fileName) = File::Spec->splitpath( $inFile );
	push @inFiles,$fileName;
	}

if ($seqType eq 'dna') 
	{$giField='gi';$seqTable='seqs';$seqField='seq';$lengthField='length'} 
else 
	{$giField='gi_aa';$seqTable='aas';$seqField='seq_aa';$lengthField='length_aa'} # set the right query field

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;
$nodeTable= "nodes_$release";
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


for $file (@inFiles)
{

$minL = 1000000; $maxL = 0;
undef %n_unambig_H;
undef %taxon_nameH;
undef %gis_of_ti_HoA;
undef %ti_of_giH;
undef %gis_per_tiH;
undef %genusH;
undef %gis_of_genus_ti_HoA;
undef %best_gi_of_tiH;
undef %best_gi_of_ti_genusH;

$inFile = File::Spec->catfile($inFileDir,$file);
open FH, "<$inFile";
$first=1;
while (<FH>)
	{
	chomp;

	if ($inFormat eq 'gi')
		{ $gi = $_ ; }
	else
		{  ($root,$cl,$cl_type,$gi,$ti) = split; }

	if ($first)
		{
		$repGI1 = $gi; # keep a list of one gi per file
		$first=0;
		}


	$sqls="select $seqField,$lengthField,ti from $seqTable where $giField=$gi";
	$shs = $dbh->prepare($sqls);
	$shs->execute;
	($seq,$seqL,$ti) = $shs->fetchrow_array ; 
	if (! defined $ti)
		{
		++$missingGIs;
		next;
		}
	$seqH{$gi}=$seq;
	$n_unambigH{$gi}=numUnambig($seq,$seqType);

	next if ($n_unambigH{$gi} < $minUnambigFilter);

	$sqls="select taxon_name,ti_genus from $nodeTable where ti=$ti";
	$shs = $dbh->prepare($sqls);
	$shs->execute;
	($taxon_name,$ti_genus) = $shs->fetchrow_array;
	$shs->finish;

	if ($exclude_sp && $taxon_name =~ /\ssp\.\s/)
		{print "Excluding $taxon_name\n"; next;}

	$taxon_nameH{$ti}=$taxon_name;	
	push @{ $gis_of_ti_HoA{$ti} }, $gi;
	$ti_of_giH{$gi}=$ti;
	$gis_per_tiH{$ti}++;
	$genusH{$ti_genus}=1;
	$cumul_genusH{$ti_genus}=1;
	push @{ $gis_of_genus_ti_HoA{$ti_genus} }, $gi;
	if ($seqL < $minL) {$minL = $seqL};
	if ($seqL > $maxL) {$maxL = $seqL};
	}
@all_gis = keys %ti_of_giH;
$numGIs = @all_gis;
$numTIs = keys %taxon_nameH;
$numGenera = keys %genusH;
$cumul_numGenera = keys %cumul_genusH;
next if ($numGenera < $min_genera);
next if ($numTIs < $min_TIs);
next if ($minL < $min_L);

print "$file: GIs:$numGIs\tTIs:$numTIs\tGenera:$numGenera (cumul:$cumul_numGenera)\tMin Seq Length:$minL\tMax Seq Length:$maxL\tgi$repGI1\n";

push @repGI, $repGI1; # keep that one rep gi from the file if it passes the filter

if ($print_taxa)
	{
	@sorted_names = sort values %taxon_nameH;
	for $name (@sorted_names) {print "$name\n"};
	}

# Now do grouping by TI or genus as needed
if ($one_per_ti)
    {
    foreach $ti (keys %gis_of_ti_HoA)
	{
	$maxUn=0;
	for $gi (  @{$gis_of_ti_HoA{$ti}} )
		{
		if ($n_unambigH{$gi} > $maxUn)
			{
			$maxUn = $n_unambigH{$gi};
			$bestGI= $gi;
			}		
		}
	$best_gi_of_tiH{$ti}=$bestGI;
	}
    @all_gis = values %best_gi_of_tiH;
    }
if ($one_per_genus)
    {
    foreach $ti_genus (keys %gis_of_genus_ti_HoA)
	{
	$maxUn=0;
	for $gi ( @{$gis_of_genus_ti_HoA{$ti_genus}})
		{
		if ($n_unambigH{$gi} > $maxUn)
			{
			$maxUn = $n_unambigH{$gi};
			$bestGI= $gi;
			}		
		}
	$best_gi_of_ti_genusH{$ti_genus}=$bestGI;
	}
    @all_gis = values %best_gi_of_ti_genusH;
    }

if ($aaFile && $seqType eq 'aa')
	{
	open FHO, ">$aaFile";
	for $gi (@all_gis)
		{
		$sqls="select $seqField from $seqTable where $giField=$gi";
		$shs = $dbh->prepare($sqls);
		$shs->execute;
		($seq) = $shs->fetchrow_array;
		$def = form_taxon_name($gi,$taxLabelsOption);
		print FHO ">$def\n$seq\n";
		$shs->finish;
		}
	close FHO;
	}
if ($dnaFile && $seqType eq 'aa')
	{
	open FHO, ">$dnaFile.dna";
	#open FH1, ">$dnaFile.aa";
	for $gi (@all_gis)
		{
		($seq_dna,$seq_aa) = extract_CDS($gi);
		$def = form_taxon_name($gi,$taxLabelsOption);
		print FHO ">$def\n$seq_dna\n";
		#print FH1 ">$def\n$seq_aa\n";
		}
	close FHO;
	#close FH1;
	}
if ($dnaFile && $seqType eq 'dna')
	{
	open FHO, ">$dnaFile";
	for $gi (@all_gis)
		{
		$def = form_taxon_name($gi,$taxLabelsOption);
		print FHO ">$def\n$seqH{$gi}\n";
		}
	close FHO;
	}
close FH;
}

print "Missing GIs = $missingGIs\n";

#print "@repGI\n";

# Return the number of unambiguous sites in a seq
sub numUnambig
{
my ($s,$type) = @_;
my $count=0;
$symbolsDNA = '[ACGT]';
$symbolsAA = '[ACDEFGHIKLMNPQRSTVWY]';
if ($type eq 'aa') 
	{$symbols=$symbolsAA}
else
	{$symbols=$symbolsDNA}
$count++ while $s =~ /$symbols/gi; # case INSENSITIVE
return $count;
}

sub form_taxon_name
{
my ($gi,$option)=@_;
my ($t,$name);
if ($option eq 'gi') {return "gi$gi"}
if ($option eq 'giti') {return "gi$gi\_ti$ti_of_giH{$gi}"}
if ($option eq 'all') 
	{
	$name = $taxon_nameH{$ti_of_giH{$gi}};
	$name =~ s/\'//g;
	$t="\'gi$gi\_ti$ti_of_giH{$gi} $name\'";
	return $t;
	}
}


# Extracts from the PB the DNA sequence corresponding to an AA translation.

# The "range" specifier together with "codon_start" tells us how to deal with this stuff.
# The prefix is handled via codon_start. I handle the suffix by merely removing anything after
# an even multiple of 3 at the end. 
# NB. NCBI's translations remove the stop codon and hence are one triplet shorter than the DNA
# ranges suggest. I check for terminal codons TAA TAG TGA and delete them if present

# An NCBI gotcha: sometimes they will deduce the last AA even based on only two nucleotides if that is possible
# from the genetic code. This is another reason the dna lengths and aa lengths are not predictable from each other.
# Try ignoring this and see if tranalign will handle ok if I just remove stop codons from dna

sub extract_CDS
		{
		my ($gi_aa)=@_; # starting with the AA gi
		$sql="select gi, length_aa, codon_start, range from aas where gi_aa=$gi_aa";
		$sh = $dbh->prepare($sql);
		$sh->execute;
		my ($gi,$length_aa,$codon_start,$range) = $sh->fetchrow_array;  # get the AA stuff

		$sql="select length, seq from seqs where gi=$gi"; # now get the DNA CDS
		$sh = $dbh->prepare($sql);
		$sh->execute;
		($length_dna,$seq_dna) = $sh->fetchrow_array;  # only returns one row (presumably) here and next...

	#	$CDS = extract($range,$codon_start, $length_aa, $seq_dna);
# STILL THE CODON START...
#print "$gi_aa\n";
		my ($CDS_dna, $CDS_aa) = extract_CDS_bioperl($range,$codon_start,$seq_dna);
		return ($CDS_dna, $CDS_aa);
		}

sub extract
{
my ($range,$codon_start, $length_aa, $seq)=@_;

if ($range =~ /join/ || $range =~ /complement/) 
	{
	die "Didn't parse complex range statement in CDS feature: $range\n";
	}
($first,$last) = ($range =~ /(\d+)\.\.[<>]?(\d+)/);
$xlength = $last - ($first-1 + $codon_start - 1) + 1 ;
$s = substr ($seq, $first -1 + $codon_start -1, $xlength); # start of first codon to end of CDS whether that's codon end or not
$remainder = $xlength %  3; 
if ($remainder == 0) {$hanging=3} else {$hanging=$remainder}; # how many bases are in the last codon in the range?
if ($hanging==3)  # remove this codon if its a stop
	{
	$last_codon = substr($s, -$hanging); # get the last $hanging characters
	if ($last_codon =~ /(TAA)|(TAG)|(TGA)/i)
		{
		$s = substr ($s,0,length($s)-3);
		}
	}
return $s;
}


sub extract_CDS_bioperl
{
my ($range,$codon_start, $seqin)=@_;
 
my ($frame)=$codon_start-1; # convention in bioperl vs ncbi
my $nuc_obj = Bio::Seq->new(-seq => $seqin, -alphabet => 'dna' );
my $loc_factory = Bio::Factory::FTLocationFactory->new;
my $loc_object = $loc_factory->from_string($range);


my $feat_obj = Bio::SeqFeature::Generic->new(-location =>$loc_object,-frame =>$frame);
$nuc_obj->add_SeqFeature($feat_obj);
my $cds_obj = $feat_obj->spliced_seq;
my $cds_dna=$cds_obj->seq;
my $trimmed_dna_obj = $cds_obj->trunc($codon_start,$cds_obj->length);
$xlength = $trimmed_dna_obj->length;
$remainder = $xlength %  3; 
if ($remainder == 0) 
	{
	my $trimmed_dna = $trimmed_dna_obj->seq;
	$last_codon = substr($trimmed_dna, -3); 
	if ($last_codon =~ /(TAA)|(TAG)|(TGA)/i)
		{
		$trimmed_dna_obj = $trimmed_dna_obj->trunc (1,$xlength-3);
		}
	}
else
	{
	$trimmed_dna_obj = $trimmed_dna_obj->trunc(1,$xlength-$remainder);
	}

my $trimmed_dna = $trimmed_dna_obj->seq;
my $trimmed_aa   = $trimmed_dna_obj->translate->seq;
#print "$range\t";
#if ($codon_start != 1) {print "codon_start=$codon_start\n"} else {print "\n";}
#print "$seqin\n";
#print "$trimmed_dna\n";
#print "$trimmed_aa\n";
if (length($trimmed_dna) != 3*length($trimmed_aa))
	{die "Mismatch count between dna and aa\n"}
if ($trimmed_aa =~ /\*/) 
	{die "Found a stop codon in the aa sequence\n"}
return ($trimmed_dna,$trimmed_aa);
}

