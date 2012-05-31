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