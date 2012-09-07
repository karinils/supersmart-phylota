#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Matrices::Matrix;
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use Data::Dumper;

# BEWARE: this is a lengthy test to run!

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new( '-level' => INFO, '-class' => 'main' );
$log->warn('BEWARE: this is a lengthy test to run!');

# the first tests: can we use and instantiate the MarkersAndTaxaSelector
BEGIN { use_ok('Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector'); }
my $mts = new_ok('Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector');
$log->VERBOSE(
	'-level' => INFO,
	'-class' => 'Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector',
);

# we are going to read the text files in the results/specieslists dir,
# so we first need its location based on the system config, see phylota.ini
my $config = Bio::Phylo::PhyLoTA::Config->new;
my $file = $config->RESULTS_DIR . '/specieslists/atestlist.txt';
$log->info("going to read species names from $file");

# read names from file, clean line breaks
open my $fh, '<', $file or die $!;
my @names = <$fh>;
chomp(@names);
$log->info("read species names from $file");

# this will take some time to do the taxonomic name resolution in the
# database and with webservices
my @nodes = $mts->get_nodes_for_names(@names);
ok( @nodes );

# this is sorted from more to less inclusive
my @clusters = $mts->get_clusters_for_nodes(@nodes);
ok( @clusters );

# now build the alignments
my $i = 1;
my %ti = map { $_->ti => 1 } @nodes;

# iterate over matching clusters
for my $cl ( @clusters ) {
	$log->info("going to fetch sequences for cluster $cl");
	
	# fetch ALL sequences for the cluster, reduce data set
	my $sg = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new;
	my @seqs = $sg->filter_seq_set($sg->get_sequences_for_cluster_object($cl));
	$log->info("fetched ".scalar(@seqs)." sequences");
	
	# keep only the sequences for our taxa
	my @matching = grep { $ti{$_->ti} } @seqs;
	
	# let's not keep the ones we can't build trees out of
	if ( scalar @matching > 3 ) {
		
		# build taxonomy tree
		my @nodes_in_matching = map { $_->get_taxon->set_generic( 'gi' => 's' . $_->get_id ) } @matching;
		my $tree = $mts->get_tree_for_nodes(@nodes_in_matching);
		my $newick = $tree->to_newick( '-tipnames' => 'gi' );
		$log->info("created newick string");
		
		# create out file name
		my $treefile = $file;
		$treefile =~ s/\.txt$/.$i.dnd/;
		open my $treefh, '>', $treefile or die $!;
		print $treefh $newick, "\n";
		close $treefh;
		$log->info("wrote starting tree $i to $treefile");
		
		# this runs muscle, so should be on your PATH.
		# this also requires bioperl-live and bioperl-run
		$log->info("going to align sequences");
		my $aln = $sg->align_sequences(@matching);
		$log->info("done aligning");
		
		# convert AlignI to matrix for pretty NEXUS generation
		my $m = Bio::Phylo::Matrices::Matrix->new_from_bioperl($aln);
		
		# create out file name
		my $outfile = $file;
		$outfile =~ s/\.txt$/.$i.phylip/;
		open my $outfh, '>', $outfile or die $!;
		
		# iterate over all matrix rows
		my $ntax  = $m->get_ntax;
		my $nchar = $m->get_nchar;
		print $outfh "$ntax $nchar\n";
		$m->visit(sub{					
			my $row = shift;
			
			# the GI is set as the name by the alignment method
			my $gi  = $row->get_name;			
			my $seq = $row->get_char;
			print $outfh "s$gi $seq\n";
		});
		
		# done writing
		close $outfh;
		
		# done
		$log->info("wrote alignment $i to $outfile");
		$i++;
	}
}