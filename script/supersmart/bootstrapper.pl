#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::PhyLoTA::Domain::BigTree;
use Bio::Phylo::PhyLoTA::Domain::MarkersAndTaxa;

# process command line arguments
my ( $dir, $replicates, $verbosity, $seqfile, $treefile ) = ( '.', 100, WARN );
GetOptions(
	'dir=s'        => \$dir,
	'replicates=i' => \$replicates,
	'seqfile=s'    => \$seqfile,
	'treefile=s'   => \$treefile,
	'verbose+'     => \$verbosity,
);

# instantiate helper objects
my $btr = Bio::Phylo::PhyLoTA::Domain::BigTree->new;
my $mts = Bio::Phylo::PhyLoTA::Domain::MarkersAndTaxa->new;
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# parse fasta file
my %fasta = $mts->parse_fasta_file($seqfile);
$log->info("read FASTA data from $seqfile");

# compute number of characters
my ($nchar) = map { length($_) } values %fasta;
my $ntax = scalar keys %fasta;

# create file stem
my $base = basename($seqfile);
my $stem = $dir . '/' . $base;

#Êone-based
my @treefiles;
for my $i ( 1 .. $replicates ) {
	my $bootstrap_file = $stem . '.rep' . $i . '.phy';
	$log->info("going to run bootstrap replicate $i ($bootstrap_file)");
	
	# create an array of indices sampled with replacement
	my @indices;
	while (scalar(@indices) < $nchar ) {
		push @indices, int rand $nchar;
	}
	my @sorted = sort { $a <=> $b } @indices;
	
	# write the bootstrapped data set as PHYLIP
	open my $fh, '>', $bootstrap_file;
	print $fh "$ntax $nchar\n";
	for my $row ( keys %fasta ) {
		my @seq = split //, $fasta{$row};
		my $boostrapped = join '', @seq[@sorted];
		if ( my $row =~ /taxon\|(\d+)/ ) {
			my $taxon = $1;
			print $fh $taxon, ' ' x ( 10 - length($taxon) ), $bootstrapped, "\n";
		}
	}
	close $fh;
	
	# run the search
	push @treefiles, $btr->build_tree(
		'-seq_file'  => $bootstrap_file,
		'-tree_file' => $treefile,
		'-work_dir'  => $dir,
	);
}

# now what we need to do is compute a majority-rule consensus over the files in @treefiles