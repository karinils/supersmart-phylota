#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

BEGIN{ use_ok('Bio::Phylo::PhyLoTA::DAO'); }
my $obj = new_ok('Bio::Phylo::PhyLoTA::DAO');


