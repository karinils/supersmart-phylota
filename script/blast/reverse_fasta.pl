#!/usr/bin/perl

use pb;

use Bio::SeqIO;
 

while ($fl = shift @ARGV)
  {
  if ($fl eq '-f') {$faFile = shift @ARGV;}
  }
# Initialize a bunch of locations, etc.

$seqio_obj = Bio::SeqIO->new(-file => $faFile, -format => "fasta" );

while ($seq_obj = $seqio_obj->next_seq)
	{   
	$def = $seq_obj->display_id . " " . $seq_obj->desc; # this is how Bioperl makes a definition line!
#print "$def ... \n";
	$seq = $seq_obj->seq;
	$rev = reverse $seq;
	print ">$def\n$rev\n";
	}

