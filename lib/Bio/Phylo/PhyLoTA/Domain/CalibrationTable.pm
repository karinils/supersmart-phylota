# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::CalibrationTable;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless [], $class;
    return $self;
}

sub add_row {
    my ( $self, %args ) = @_;
    push @{ $self }, \%args;
}

sub to_string {
    my $self = shift;
    my $string = '';
    for my $row ( @{ $self } ) {
        $string .= join(' ', @{ $row->{taxa} }, '|', $row->{min_age}, $row->{max_age} ) . "\n";
    }
    return $string;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::CalibrationTable - Calibration table

=head1 DESCRIPTION

Object that represents a list of calibration points that can be serialized
as input for PhyTime.

=cut

