use strict;
use warnings;
use Test::More 'no_plan';
# use Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use_ok('Bio::Phylo::PhyLoTA::Service::SequenceGetter');

my $sg=new_ok('Bio::Phylo::PhyLoTA::Service::SequenceGetter');
my @sequences=$sg->get_largest_cluster_for_sequence(326632174);
my $median = $sg->compute_median_seq_length(@sequences);
ok($median == 1140);
my @filtered = $sg->filter_seq_set(@sequences);
print scalar @filtered;
# ok(@sequences==324);