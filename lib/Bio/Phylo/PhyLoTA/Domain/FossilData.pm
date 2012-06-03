# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::FossilData;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::FossilData - Fossil Data

=head1 DESCRIPTION

Table with taxon, fossil_ages [1...n].

=cut

