#!/usr/bin/perl

# Extracts from the PB the DNA sequence corresponding to an AA translation.

# outputs a fasta file with the extracted DNA seqs, and
# another fasta file with the original aa seqs, but tweaked for format, etc (remove ? for example)
# Input is a nexus file in which seqs are each on one line with no white space and taxon names also have no white space
# (see regexs to change).


# In general the dna seq looks like xx|XXX|XXX|...|XXX|x
# In other words there are prefix and suffix nucleotides that are partial codons.
# The "range" specifier together with "codon_start" tells us how to deal with this stuff.
# The prefix is handled via codon_start. I handle the suffix by merely removing anything after
# an even multiple of 3 at the end. 
# NB. NCBI's translations remove the stop codon and hence are one triplet shorter than the DNA
# ranges suggest. I check for terminal codons TAA TAG TGA and delete them if present

# An NCBI gotcha: sometimes they will deduce the last AA even based on only two nucleotides if that is possible
# from the genetic code. This is another reason the dna lengths and aa lengths are not predictable from each other.
# Try ignoring this and see if tranalign will handle ok if I just remove stop codons from dna

use DBI;
use pb;



while ($fl = shift @ARGV)
  {
  if ($fl eq '-f') {$inFile = shift @ARGV;}
  if ($fl eq '-dna') {$dnaFile = shift @ARGV;}
  if ($fl eq '-aa') {$aaFile = shift @ARGV;}
  if ($fl eq '-c') {$configFile = shift @ARGV;}
  }
# Initialize a bunch of locations, etc.

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



# Fetch the sequences and write the temporary fasta file and length file

open FH1, "<$inFile";
open FH2, ">$dnaFile";
open FH3, ">$aaFile";
$countSeqs=0;
while (<FH1>)
	{
	chomp;
	($taxon,$aa_align_seq)=split; # assumes ~ two col format
	if (($gi)=(/\_gi(\d+)\s+/)) #trap for this format
		{
		$sql="select length_aa, codon_start, range from aas where gi=$gi";
		$sh = $dbh->prepare($sql);
		$sh->execute;
		($length_aa,$codon_start,$range) = $sh->fetchrow_array;  # only returns one row (presumably) here and next...

		$sql="select length, seq from seqs where gi=$gi";
		$sh = $dbh->prepare($sql);
		$sh->execute;
		($length_dna,$seq_dna) = $sh->fetchrow_array;  # only returns one row (presumably) here and next...

		$dna_chunk = extract($range,$codon_start, $length_aa, $seq_dna);
		$xlen = length ($dna_chunk);
		$xlenaa = $xlen/3;
		print "$gi:$length_aa ($length_dna) $codon_start $range\n$dna_chunk [In this string: $xlen/$xlenaa]\n";
		print FH2 ">$taxon\n$dna_chunk\n";

		$aa_align_seq =~ s/\?/X/g; # replace nexus ? with IUPAC X if needed
		print FH3 ">$taxon\n$aa_align_seq\n";
		++$countSeqs;
		}
	}
$sh->finish;
close FH1;

sub extract
{
my ($range,$codon_start, $length_aa, $seq)=@_;

if ($range =~ /join/ || $range =~ /complement/) 
	{
	die "Didn't parse complex range statement";
	}
($first,$last) = ($range =~ /(\d+)\.\.[<>]?(\d+)/);
$xlength = $last - $codon_start + 1;
$remainder = $xlength %  3; 
if ($remainder == 0) {$hanging=3} else {$hanging=$remainder}; # how many bases are in the last codon in the range?
$s = substr ($seq, $codon_start -1, $xlength);
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

