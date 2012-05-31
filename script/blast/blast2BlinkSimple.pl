#!/usr/bin/perl

# Script that processes BLAST table output in a very simple way:
# ### MOST CURRENT VERSION: May 2011

# Takes a hit list that might have multiple hits for the same pair of sequences and 
# writes a shorter hit list table that just has one hit

# Expects BLAST output to have been saves in the -8 format

$ARGC = @ARGV;
if ($ARGC == 0) {printUsage();}

while ($fl = shift @ARGV)
  {
  if ($fl eq '-i') {$infile= shift @ARGV;}
  if ($fl eq '-o') {$outfile = shift @ARGV;}
  }

if ($infile eq "" || $outfile eq "") {die "Must supply input and output file\n";} 

open FH, "<$infile";
open FHO, ">$outfile";
while(<FH>)
	{
	($t1,$t2)=split;
	$hit = $t1."\t".$t2;
	$H{$hit}=1;
	}
close FH;
for $hit (keys %H)
	{
	print FHO "$hit\n";
	}
close FHO;
