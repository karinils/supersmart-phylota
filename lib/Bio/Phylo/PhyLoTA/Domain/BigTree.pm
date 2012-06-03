# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::BigTree;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::BigTree - Big Tree

=head1 DESCRIPTION

Tree (string) in Newick format having support values and node ages. Taxon ID’s for 
genera as leaf labels.

=cut

