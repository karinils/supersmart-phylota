#!/usr/bin/perl

while (<>)
	{
	chomp;
	($cl,$gi)=split;
	$clCount{$cl}++;
	$clRep{$cl}=$gi;
	}

for $cl (keys %clCount)
	{
	print "$cl\t$clCount{$cl}\t$clRep{$cl}\n";
	}
