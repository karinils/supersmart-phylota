#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME' => 'Bio::Phylo::PhyLoTA',
	'PREREQ_PM' => {
		'DBIx::Class'  => 0,
		'Getopt::Long' => 0,
		'Pod::Usage'   => 0,
		'Bio::Phylo'   => 0,
		'Template'     => 0,
		'Config::Tiny' => 0,
		'DBI'          => 0,
		'DBD::mysql'   => 0,
	}
);


sub MY::postamble {
	my %args = %{ shift(@_) };	
	my $result;
	eval {
		require Template;
		require Bio::Phylo::PhyLoTA::Config;
		$args{'conf'} = Bio::Phylo::PhyLoTA::Config->new('conf/phylota.ini');
		my $tt = Template->new();
		$tt->process('Makefile.tmpl',\%args,\$result) || die $tt->error;
	};
	if ( $@ ) {
		warn "*** Couldn't create extended Makefile.\n",
		     "*** Re-run $0 after resolving missing dependencies.\n",
		     "*** The error message we got was:\n $@";
		return undef;
	}
	else {
		return $result;
	}
}

