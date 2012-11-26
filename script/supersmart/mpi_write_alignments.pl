#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Parallel::MPI::Simple;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Matrices::Matrix;
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;
use constant HEAD_NODE => 0;
use constant CLUSTER_SUBSET => 1;
use constant ALIGNMENTS_SUBSET => 2;
use constant NODE_MAP => 3;

# process command line arguments
my $verbosity = WARN;
my ( $infile, $stem );
GetOptions(
	'infile=s' => \$infile,
	'stem=s'   => \$stem,
	'verbose+' => \$verbosity,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => [qw(
		main
		Bio::Phylo::PhyLoTA::Service::SequenceGetter
		Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector
	)]
);

# here we start in parallel mode
MPI_Init();
my $rank = MPI_Comm_rank(MPI_COMM_WORLD);

# the following block is executed by the head node
if ( $rank == 0 ) {
    
    # instantiate helper object
    my $mts = Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector->new;

    # instantiate nodes from infile
    my @nodes = $mts->get_nodes_for_table( '-file' => $infile );

    # this is sorted from more to less inclusive
    my @clusters = $mts->get_clusters_for_nodes(@nodes);

    # now build the alignments
    my %ti = map { $_->ti => 1 } @nodes;    
    
    # MPI_Comm_size returns the total number of nodes. Because we have one
    # head node this needs to be - 1
    my $nworkers = MPI_Comm_size(MPI_COMM_WORLD) - 1;
    $log->info("we have $nworkers nodes available");
    
    # for each worker we dispatch an approximately equal chunk of clusters.
    my $nclusters = int( scalar(@clusters) / $nworkers );
    $log->info("each worker will process about $nclusters clusters");
    
    # this is the starting index of the subset
    my $start = 0;
    
    # iterate over workers to dispatch jobs
    for my $worker ( 1 .. $nworkers ) {
        
        # first send over the map of nodes to keep
	MPI_Send(\%ti,$worker,NODE_MAP,MPI_COMM_WORLD);
        
	# the ending index of the subset is either the starting index + chunk size or the
	# highest index in the array, whichever fits
	my $end  = ( $start + $nclusters ) > $#clusters ? $#clusters : ( $start + $nclusters );
	
	# create subset
	my @subset = @clusters[ $start .. $end ];
	$log->info("dispatching ".scalar(@subset)." clusters (index: $start .. $end) to worker $worker");
	MPI_Send(\@subset,$worker,CLUSTER_SUBSET,MPI_COMM_WORLD);
	
	# increment starting index
	$start += $nclusters + 1;
    }
    
    # iterate over workers to receive and write results
    my $i = 1;
    for my $worker ( 1 .. $nworkers ) {
	
	# get the result
	my $result = MPI_Recv($worker,ALIGNMENTS_SUBSET,MPI_COMM_WORLD);
	$log->info("received ".scalar(@{$result})." results from worker $worker");
	
	# iterate over alignments
	for my $alignment ( @{ $result } ) {
            
            # create out file name
	    my $outfile = $stem . $i;
            
            # print name to stdout so we can make a list of produced files
            print $outfile, "\n";
            
            # open write handle
	    open my $outfh, '>', $outfile or die $!;
	    
            # iterate over rows in alignment
            for my $row ( @{ $alignment } ) {
                
                # 0 is FASTA header, 1 is aligned sequence data
                print $outfh $row->[0], "\n", $row->[1], "\n";
            }
            
            $i++;
	}
    }    
}

# this block is executed by worker nodes
else {
    
    # first receive the map of nodes to keep
    my $ti = MPI_Recv(0,NODE_MAP,MPI_COMM_WORLD);
    
    # then receive the list of clusters to process
    my $subset = MPI_Recv(0,CLUSTER_SUBSET,MPI_COMM_WORLD);
    
    # iterate over clusters, build result
    my @result;
    for my $cl ( @{ $subset } ) {
        $log->info("worker $rank going to fetch sequences for cluster $cl");
        
        # fetch ALL sequences for the cluster, reduce data set
        my $sg = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new;
        my @seqs    = $sg->filter_seq_set($sg->get_sequences_for_cluster_object($cl));
        my $single  = $sg->single_cluster($cl);
        my $seed_gi = $single->seed_gi;
        $log->info("worker $rank fetched ".scalar(@seqs)." sequences");
        
        # keep only the sequences for our taxa
        my @matching = grep { $ti->{$_->ti} } @seqs;
        
        # let's not keep the ones we can't build trees out of
        if ( scalar @matching > 3 ) {
                
            # this runs muscle, so should be on your PATH.
            # this also requires bioperl-live and bioperl-run
            $log->info("worker $rank going to align sequences");
            my $aln = $sg->align_sequences(@matching);
            $log->info("worker $rank done aligning");
            
            # convert AlignI to matrix for pretty NEXUS generation
            my $m = Bio::Phylo::Matrices::Matrix->new_from_bioperl($aln);
            
            # iterate over all matrix rows
            my @matrix;
            $m->visit(sub{					
                my $row = shift;
                
                # the GI is set as the name by the alignment method
                my $gi  = $row->get_name;
                my $ti  = $sg->find_seq($gi)->ti;
                my $seq = $row->get_char;
                push @matrix, [ ">gi|${gi}|seed_gi|${seed_gi}|taxon|${ti}" => $seq ];
            });
            push @result, \@matrix;                
        }
    }
    
    # return result
    MPI_Send(\@result,HEAD_NODE,ALIGNMENTS_SUBSET,MPI_COMM_WORLD);    
}

# we need to exit cleanly by making this call on all nodes
MPI_Finalize();