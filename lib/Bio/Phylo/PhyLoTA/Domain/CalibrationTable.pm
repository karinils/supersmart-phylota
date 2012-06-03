# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::CalibrationTable;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::CalibrationTable - Calibration table

=head1 DESCRIPTION

Table containing: order, family, genus. 

=cut

