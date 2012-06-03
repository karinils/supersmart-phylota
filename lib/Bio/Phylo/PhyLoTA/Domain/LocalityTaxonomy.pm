# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::LocalityTaxonomy;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::LocalityTaxonomy - Locality Taxonomy

=head1 DESCRIPTION

Table with species distribution data from GBIF (www.gbif.org).

=cut

