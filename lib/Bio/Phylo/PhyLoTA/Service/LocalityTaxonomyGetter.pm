package Bio::Phylo::PhyLoTA::Service::LocalityTaxonomyGetter;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}

sub get_localities_for_taxon {
    my ( $self, $taxon ) = @_;
    if ( my $gbif = $taxon->gbif ) {
        
        # do occurrence lookup
        # parse gbif result
        # return LocalityTaxonomy objects
    }
    else {
        
    }
}

sub get_gbif_for_taxon {
    my ( $self, $taxon ) = @_;
    if ( my $gbif = $taxon->gbif ) {
        return $gbif;
    }
    else {
        # do name lookup
        # parse gbif result
        # return gbif id
    }
}


1;