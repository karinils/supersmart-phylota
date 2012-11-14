#!/usr/bin/perl
use strict;
use warnings;
use File::Copy;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;

# process command line arguments
my ( $list, $stem );
my $verbosity = WARN;
GetOptions(
	'list=s'   => \$list,
	'stem=s'   => \$stem,
	'verbose+' => \$verbosity,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => [
		'main',
		'Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector',
		'Bio::Phylo::PhyLoTA::Service::SequenceGetter',
	],
	'-level' => $verbosity,
);
my $mts = Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector->new;
my $sg  = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new;

# read list of files
my @list;
{
	my $fh; # file handle
	
	# may also read from STDIN, this so that we can pipe 
	if ( $list eq '-' ) {
		$fh = \*STDIN;
		$log->debug("going to read file names from STDIN");
	}
	else {
		open $fh, '<', $list or die $!;
		$log->debug("going to read file names from $list");
	}
	
	# read lines into array
	@list = <$fh>;
	chomp @list;
}

# iterate over list of file names
my %matrices;
my %protid_for_seed_gi;
for my $file ( @list ) {

	# read seed gi from alignment
	my $seed_gi = read_seed_gi($file);
	$log->debug("read seed GI $seed_gi from file $file");
	
	# have seen this already
	if ( my $protid = $protid_for_seed_gi{$seed_gi} ) {
		$log->warn("already seen $seed_gi, found prot id $protid");
		push @{ $matrices{$protid} }, $file;
	}
	
	# do protein translation
	eval {
		if ( my $aa = $sg->get_aa_for_sequence($seed_gi) ) {
			$log->debug("seed GI $seed_gi has protein translation: $aa");
			
			# run blast
			if ( my @hits = $sg->run_blast_search( '-seq' => $aa ) ) {
				
				# store file name under protid of best inparanoid hit
				if ( $hits[0] and $hits[0]->count > 0 ) {
					$log->debug("seed GI $seed_gi has BLAST hits");
					
					# fetch and store protein id
					my $protid = $hits[0]->next->protid;
					$protid_for_seed_gi{$seed_gi} = $protid;
					
					$log->debug("seed GI $seed_gi has best hit $protid");
					if ( not $matrices{$protid} ) {
						$matrices{$protid} = [];
					}
					push @{ $matrices{$protid} }, $file;
				}
			}
		}
	};
	if ( $@ ) {
		$log->warn("couldn't fetch AA for sequence $seed_gi from file $file: $@");
	}
}

# here we do all pairwise comparisons between inparanoid protein IDs to assess
# orthology. if a pair is orthologous, we append matrix2 to matrix1 so the
# %matrices hash shrinks
my @protids = keys %matrices;
for my $i ( 0 .. $#protids ) {
	my $p1 = $protids[$i];
	
	# the hash shrinks as we get farther into the loop, so we need to check
	# to make sure it still makes sense to do the pairwise comparison
	if ( $matrices{$p1} ) {
		$log->info("going to cluster InParanoid protein ID $p1");
	
		# fetch inparanoid result set 1
		my @irs1 = $sg->search_inparanoid({ 'protid' => $p1 })->all;
		$log->debug("fetched ".scalar(@irs1). " InParanoid records for $p1");
		
		# we start at $i + 1 so that we only do the pairwise comparison
		# in one direction
		for my $j ( $i + 1 .. $#protids ) {
			my $p2 = $protids[$j];
			
			# again, this may have shrunk too
			if ( $matrices{$p2} ) {
				$log->debug("going to assess if $p1 and $p2 are orthologous");
				
				# fetch inparanoid result set 2
				my @irs2 = $sg->search_inparanoid({ 'protid' => $p2 })->all;
				$log->debug("fetched ".scalar(@irs2). " InParanoid records for $p2");
				
				# the inparanoid tables have multiple occurrences of each
				# protein ID, namely for each pairwise comparison between
				# genomes. We are looking for the instance where the two 
				# protein IDs occur because they are the ones being compared
				PAIR: for my $k ( 0 .. $#irs1 ) {
					for my $l ( 0 .. $#irs2 ) {
						
						# this test verifies that the two protein IDs occur
						# because they are being compared, and that the
						# bootstrap value of the comparison is 100%
						if ( $irs1[$k]->is_orthologous($irs2[$l]) ) {
							$log->info("$p1 and $p2 are orthologous");
							
							# append the matrix or matrices from inparanoid
							# protein ID 1 to the ones from ID 1
							push @{ $matrices{$p1} }, @{ $matrices{$p2} };
							delete $matrices{$p2};
							last PAIR;
						}
					}
				}
			}
		}
	}
}

=begin comment

Now each list of files (value of %matrices hash) must be profile-aligned if
there is more than one (perhaps iteratively so) until there are only singletons
left, which are concatenated and joined on taxon IDs

=cut

# iterate over InParanoid protein IDs
for my $protid ( keys %matrices ) {
	
	# fetch list of file names orthologous with that protid
	my @file = @{ $matrices{$protid} };
	$log->info("there are ".scalar(@file)." clusters orthologous with $protid");
	
	# the files in the list will become a profile-profile MSA under this name
	my $outfile = "${stem}-${protid}.fa";
	
	# check to see there are actually multiple files to align
	if ( @file > 1 ) {
		my @tmpfiles;
		for my $i ( 0 .. $#file ) {
			
			# we want to grow the profile alignment cumulatively, so for each
			# steo we create a temporary outfile that becomes the first of the
			# two infiles in the next step
			if ( $file[$i + 1] ) {
				my $tmpfile = "${outfile}.tmp.${i}";
				$log->info("aligning ".$file[$i]." and ".$file[$i + 1]." to $tmpfile");
				
				# perhaps this is better done using bioperl-run's alignment
				# wrapper - except we don't need to read the results in this
				# script and we had some problems with the wrapper elsewhere
				# (particularly with the -profile flag) so we'll just do the
				# invocation directly.
				system(
					'muscle' => '-profile',
					'-in1'   => $file[$i],
					'-in2'   => $file[$i + 1],
					'-out'   => $tmpfile,
					'-quiet',
				);
				
				# by doing this the result of the current alignment becomes
				# -in1 for the next iteration
				$file[$i + 1] = $tmpfile;
				
				# this so that we can clean up the temp files
				push @tmpfiles, $tmpfile;
			}
			else {
				
				# if there is no $file[$i + 1], it means that $file[$i] was
				# the alignment result of the previous iteration, which has
				# accumulated all preceding files, and should therefore become
				# the outfile
				copy( $file[$i], $outfile );				
				# unlink @tmpfiles; # clean tmp files
			}
		}
	}
	else {
		copy( $file[0], $outfile );
	}
	
	# we print out the resulting merged alignment's name, so that we can re-
	# direct these names into a listing that can become the input for the next
	# script, which will join the alignments on taxon IDs.
	print $outfile, "\n";
	
	# done
	$log->info("created merged alignment $outfile");
}

# reads the seed GI, which is in the FASTA definition line 
sub read_seed_gi {
	my $file = shift;
	my $seed_gi;
	open my $fh, '<', $file or die $!;
	while(<$fh>) {
		chomp;
		if ( /seed_gi\|(\d+)/ ) {
			$seed_gi = $1;
			return $seed_gi;
		}
	}
}