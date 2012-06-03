# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::LocalityTaxonomyGetter;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Service::LocalityTaxonomyGetter - Locality Taxonomy Getter

=head1 DESCRIPTION

Downloads species distribution data from GBIF (www.gbif.org).

=cut