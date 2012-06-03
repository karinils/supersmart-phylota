# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Service::SequenceGetter - Sequence Getter

=head1 DESCRIPTION

Gets sequences for all species from Genbank (www.ncbi.nlm.nih.gov).

=cut