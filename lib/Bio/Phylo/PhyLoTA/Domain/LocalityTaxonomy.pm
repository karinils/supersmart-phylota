# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::LocalityTaxonomy;
use strict;
use warnings;

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $specimen = shift;
    my $self = bless \$specimen, $class;
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.+://;
    return $$self->$method(@_);
}

1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::LocalityTaxonomy - Locality Taxonomy

=head1 DESCRIPTION

Table with species distribution data from GBIF (www.gbif.org).

=cut

