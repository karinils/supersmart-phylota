package Bio::Phylo::PhyLoTA::Service::SequenceGetter; # maybe this should be SequenceService?
use strict;
use warnings;
use Bio::Phylo::PhyLoTA::DAO;
use Bio::Phylo::PhyLoTA::Config;

my $schema = Bio::Phylo::PhyLoTA::DAO->new;
my $config = Bio::Phylo::PhyLoTA::Config->new;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}

# stores a bioperl sequence object, if optional second argument is true we
# won't store the raw sequence string (because it would be too long). returns
# the newly created dao Seq object
sub store_sequence {
    my ( $self, $bioperl_seq, $no_raw ) = @_;
    my @dates = $bioperl_seq->get_dates();
    return $schema->resultset('Seq')->create( {
        'acc_date' => _formatDate( $dates[-1] ),
        'gbrel'    => $config->currentGBRelease,
        'seq'      => $no_raw ? undef : $bioperl_seq->seq,        
        'acc'      => $bioperl_seq->accession_number,
        'acc_vers' => $bioperl_seq->seq_version,
        'def'      => $bioperl_seq->desc,
        'division' => $bioperl_seq->division,
        'gi'       => $bioperl_seq->primary_id,
        'length'   => $bioperl_seq->length,
        'ti'       => $bioperl_seq->species->ncbi_taxid
    });
}

sub _formatDate {
    my %monthH = (
        JAN => 1,
        FEB => 2,
        MAR => 3,
        APR => 4,
        MAY => 5,
        JUN => 6,
        JUL => 7,
        AUG => 8,
        SEP => 9,
        OCT => 10,
        NOV => 11,
        DEC => 12
    );
    my ( $day, $month, $year ) = split '\-', $_[0];
    return "$year-$monthH{$month}-$day";
}

1;