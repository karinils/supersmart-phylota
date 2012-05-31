#!/usr/bin/perl

while (<>)
	{
	chomp;
	$gi_aa=$_;
	$s = " qsub ./pb_blast_against_node.pl -t 3803 -c pb.conf.aa -gi $gi_aa" ; 
	#print "$s\n";
	system ($s);
	}
