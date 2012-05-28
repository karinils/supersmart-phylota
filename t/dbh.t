#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

BEGIN { use_ok('Bio::Phylo::PhyLoTA::DBH'); }
my $dbh = new_ok('Bio::Phylo::PhyLoTA::DBH');

for my $field ( qw(host dsn database rdbms user pass) ) {
	ok( $dbh->$field, "$field is defined" );
}


