#!/usr/bin/perl
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	'PREREQ_PM' => {
		'DBIx::Class'  => 0,
		'Getopt::Long' => 0,
		'Pod::Usage'   => 0,
		'Bio::Phylo'   => 0,
		'Template'     => 0,
	}
);


