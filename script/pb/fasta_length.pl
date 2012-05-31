#!/usr/bin/perl

# Read a fasta file that has giXXX in the def line, lookup ti and name and possibly sort and filter using a list of gis

# I am now using the convention that dna has 'giXXX' and aa has 'gi_aaXXX'. This refers only to which database at NCBI to find these seqs!


use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;

use Bio::SeqIO;
 
$gisAA = 0; # default treat gi# as referring to nuc database

while ($fl = shift @ARGV)
  {
  if ($fl eq '-f') {$faFile = shift @ARGV;}
  }

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;


$seqio_obj = Bio::SeqIO->new(-file => $faFile, -format => "fasta" );

while ($seq_obj = $seqio_obj->next_seq)
	{   
	$def = $seq_obj->display_id . " " . $seq_obj->desc; # this is how Bioperl makes a definition line!
	$seq = $seq_obj->seq;
	if (($gi)=($def=~/gi(\d+)/))
		{
		print "$gi\t",length($seq)."\n";
		}
	}

