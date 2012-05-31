#!/usr/bin/perl

# Reads a fasta file and writes a new fasta file with a simple defline and a length
# file that has two columns: gi# and sequence length

# Expects defline to begin with >gi####or >gi|#### and reports in gi### format
# Usage: ./fastaProcess infastafile outfasta outlength

open FHin, "<$ARGV[0]" or die "Input fasta file was not found\n";
open FHfaout, ">$ARGV[1]";
open FHfalen, ">$ARGV[2]";

$L=0;
$first=1;
while (<FHin>)
	{
	if ( ($gi)=/>gi(\d+)/)
		{
		if (!$first) {print FHfalen "$L\n"; $L=0};
		print FHfaout ">gi$gi\n";
		print FHfalen "gi$gi\t";
		}
	elsif ( ($gi)=/>gi\|(\d+)/)
		{
		if (!$first) {print FHfalen "$L\n"; $L=0};
		print FHfaout ">gi$gi\n";
		print FHfalen "gi$gi\t";
		}
	else
		{
		print FHfaout;
		chomp;
		s/\s+//g;
		$L+=length($_);
		}	
	$first=0;
	}
if (!$first) {print FHfalen "$L\n"};
