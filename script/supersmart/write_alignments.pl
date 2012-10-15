#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Matrices::Matrix;
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;

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
my $mts = Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector->new;

# read names from file or STDIN, clean line breaks
my @names;
if ( $infile eq '-' ) {
	@names = <STDIN>;
	chomp(@names);
	$log->info("read species names from STDIN");
}
else {
	open my $fh, '<', $infile or die $!;
	@names = <$fh>;
	chomp(@names);
	$log->info("read species names from $infile");
}

# this will take some time to do the taxonomic name resolution in the
# database and with webservices
my @nodes = $mts->get_nodes_for_names(@names);

# this is sorted from more to less inclusive
my @clusters = $mts->get_clusters_for_nodes(@nodes);

# now build the alignments
my $i = 1;
my %ti = map { $_->ti => 1 } @nodes;

# iterate over matching clusters
for my $cl ( @clusters ) {
	$log->info("going to fetch sequences for cluster $cl");
	
	# fetch ALL sequences for the cluster, reduce data set
	my $sg = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new;
	my @seqs    = $sg->filter_seq_set($sg->get_sequences_for_cluster_object($cl));
	my $single  = $sg->single_cluster($cl);
	my $seed_gi = $single->seed_gi;
	$log->info("fetched ".scalar(@seqs)." sequences");
	
	# keep only the sequences for our taxa
	my @matching = grep { $ti{$_->ti} } @seqs;
	
	# let's not keep the ones we can't build trees out of
	if ( scalar @matching > 3 ) {
		
		# this runs muscle, so should be on your PATH.
		# this also requires bioperl-live and bioperl-run
		$log->info("going to align sequences");
		my $aln = $sg->align_sequences(@matching);
		$log->info("done aligning");
		
		# convert AlignI to matrix for pretty NEXUS generation
		my $m = Bio::Phylo::Matrices::Matrix->new_from_bioperl($aln);
		
		# create out file name
		my $outfile = $stem . $i;
		open my $outfh, '>', $outfile or die $!;
		
		# iterate over all matrix rows
		$m->visit(sub{					
			my $row = shift;
			
			# the GI is set as the name by the alignment method
			my $gi  = $row->get_name;
			my $ti  = $sg->find_seq($gi)->ti;
			my $seq = $row->get_char;
			print $outfh ">gi|${gi}|seed_gi|${seed_gi}|taxon|${ti}\n$seq\n";
		});
		
		# done writing
		close $outfh;
		
		# done
		$log->info("wrote alignment $i to $outfile");
		print $outfile, "\n";
		$i++;
	}
}