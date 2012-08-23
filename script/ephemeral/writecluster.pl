use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Matrices::Matrix;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;

# matK: 6174789
# ITS1: 18028304
# CO1: 305690971
# rbcL: 149389752

# process command line arguments
my ( $outfile, $verbosity, $gi ) = ( \*STDOUT, WARN );
GetOptions(
    'gi=i'      => \$gi,
    'outfile=s' => \$outfile,
    'verbose+'  => \$verbosity,
);

# create a new logger object
my $log = Bio::Phylo::Util::Logger->new(
    '-class' => 'Bio::Phylo::PhyLoTA::Service::SequenceGetter',
    '-level' => $verbosity,
);

# create a new sequence getter object
my $sg = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new;

# this fetches the smallest containing cluster around the seed
my @sequences = $sg->get_smallest_cluster_for_sequence($gi);

# reduces the number of sequences in the seq by removing duplicate
# sequences and by preferentially retaining sequences of the median
# length, otherwise longer sequences and then otherwise short sequences
my @filtered = $sg->filter_seq_set(@sequences);

# align using muscle
my $align = $sg->align_sequences(@filtered);

# converts a Bio::AlignI object (as returned by muscle) into
# a matrix object that can be written to nexus
my $matrix = Bio::Phylo::Matrices::Matrix->new_from_bioperl($align);

# open a file handle
open my $fh, '>', $outfile or die $!;

# this part is a brief song and dance to make mesquite happy: a nexus
# file according to mesquite must start with a taxa block and the rows
# in the subsequence matrix must be in the same order as the taxa in the
# taxa block. The make_taxa method generates such a taxa block, but in
# alphabetical order, so we also need to sort the rows in our matrix
# in the same way.
my $taxa = $matrix->make_taxa;
my @sorted = sort { $a->get_name cmp $b->get_name } @{ $matrix->get_entities };
$matrix->clear;
$matrix->insert($_) for @sorted;

# now print out the nexus statements to our $filename
print $fh "#NEXUS\n",$taxa->to_nexus,$matrix->to_nexus;