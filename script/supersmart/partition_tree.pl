#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;

# process command line arguments
my ( $verbosity, $chunksize, $infile ) = ( WARN, 10 );
GetOptions(
    'infile=s'    => \$infile,
    'verbose+'    => \$verbosity,
    'chunksize=i' => \$chunksize,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
    '-level' => $verbosity,
    '-class' => 'main',
);
my $mts = Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector->new;

# instantiate nodes from infile
my @nodes = $mts->get_nodes_for_table( '-file' => $infile );
my %tip = map { $_->ti => 1 } @nodes;

# first get the mrca
my ( %seen, %rank );
for my $node ( @nodes ) {
    my @anc = map { $_->ti } @{ $node->get_ancestors };
    
    # ancestors are candidates to be the MRCA if they are
    # an ancestor for every node in the list
    $seen{$_}++ for @anc;
    
    # ancestors are ordered by more to less recent. here
    # we record their rank
    $rank{$anc[$_]} = $_ for 0 .. $#anc;
}
my @candidates = grep { $seen{$_} == scalar(@nodes) } keys %seen;
my ($mrca) = sort { $rank{$a} <=> $rank{$b} } @candidates;
$log->info("MRCA is $mrca");

# now fetch the mrca node object
my $mrca_node = $mts->find_node($mrca);

my ( $chunkcounter, $tipcounter, @tips, %pre ) = ( 1, 0 );
$mrca_node->visit_depth_first(
    '-pre' => sub {
        my $node = shift;
        my $ti = $node->ti;
        
        if ( $tip{$ti} ) {
            $tipcounter++;
            push @tips, $ti;
        }
        $pre{$ti} = $tipcounter;
    },
    '-post' => sub {
        my $node = shift;
        my $ti = $node->ti;
        
        my $cladesize = $tipcounter - $pre{$ti};
        
        if ( $cladesize * $chunkcounter > $chunksize ) {
            print $node->ti, "\t", join(',',@tips), "\n";
            $chunkcounter++;
        }
    }
)