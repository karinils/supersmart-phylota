# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::FossilDataGetter;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Service::FossilDataGetter - Fossil Data Getter

=head1 DESCRIPTION

Downloads relevant fields from entire Paleobiology (http://paleodb.org).

=cut