#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::GenBank;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $verbosity = WARN;
GetOptions( 'verbose+' => \$verbosity );

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);
my $gb = Bio::DB::GenBank->new;

GI: while(<>) {
	chomp;
	
	# the GI has to be an integer, ignore blank lines, headers, etc.
	next GI unless /^\d+$/;	
	my $gi = $_;
	$log->debug("going to inspect gi $gi");
	
	# because we are talking to teh interwebz let's wrap in an eval
	# to prevent sudden death
	eval {
		
		# fetch the sequence object from genbank
		my $seq = $gb->get_Seq_by_gi($gi);
		
		# iterate over sequence features
		my $is_cds;
		for my $feat ( $seq->get_SeqFeatures ) {
			
			# check to see if it's a protein coding sequence with an AA translation
			if ( $feat->primary_tag eq 'CDS' and $feat->has_tag('translation') ) {
				
				# fetch and pring the translation
				my ($protseq) = $feat->get_tag_values('translation');
				print $gi, "\t", $protseq, "\n";
				$is_cds++;
			}
		}
		$log->info("seq $gi is not a coding seq with AA translation") unless $is_cds;
	};
	if ( $@ ) {
		$log->warn("error fetching seq $gi: $@");
	}
}