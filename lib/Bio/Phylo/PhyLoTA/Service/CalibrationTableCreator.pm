# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::CalibrationTableCreator;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;


=head1 NAME

Bio::Phylo::PhyLoTA::Service::CalibrationTableCreator - Calibration Table Creator

=head1 DESCRIPTION

Queries the FossilTable for each genus received. Retrieves all fossil records for each taxon. 
Identifies the minimum age of each taxa. Returnes table containing: taxon, minimal_age, all_ages 
[1...g], prior, include [y/n]. The purpose is to create a table with suitable calibration points 
for the dating analysis.

=cut

