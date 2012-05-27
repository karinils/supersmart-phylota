#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use ExtUtils::MakeMaker;
use Bio::Phylo::PhyLoTA::Config;

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
	$args{'conf'} = Bio::Phylo::PhyLoTA::Config->new('conf/phylota.ini');
	my $result;
	eval {
		require Template;
		my $tt = Template->new();
		$tt->process('Makefile.tmpl',\%args,\$result) || die $tt->error;
	};
	if ( $@ ) {
		warn "Couldn't create Makefile postamble: $@";
		return undef;
	}
	else {
		return $result;
	}
}

