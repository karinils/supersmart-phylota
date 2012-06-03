# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector - Markers and Taxa Selector

=head1 DESCRIPTION

Selects optimal set of taxa and markers based on #markers/sp, coverage on matrix (total missing
data). User can change threshold.

=cut