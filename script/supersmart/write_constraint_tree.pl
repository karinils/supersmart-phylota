#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::Logger;
use Bio::Phylo::PhyLoTA::Domain::MarkersAndTaxa;

# process command line arguments
my ( $fasta, $treefile, $seqfile, $verbosity );
GetOptions(
	'treefile=s' => \$treefile,
	'seqfile=s'  => \$seqfile,
	'verbose+'   => \$verbosity,
	'fasta'      => \$fasta,
);

# instantiate helper objects
my $mts = Bio::Phylo::PhyLoTA::Domain::MarkersAndTaxa->new;
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# array of tip names to keep
my @keep;

# optionally we can extract the taxon identifiers from
# custom-formatted FASTA definition lines
if ( $fasta ) {
	my %fasta = $mts->parse_fasta_file($seqfile);
	@keep = $mts->get_taxa_from_fasta(%fasta);
}

# by default we parse it out of a PHYLIP file
else {
	my $header;
	open my $fh, '<', $seqfile or die $!;
	LINE: while(<$fh>){
		chomp;
		if ( not $header ) {
			$header = $_;
			next LINE;
		}
		my @line = split /\s+/, $_;
		push @keep, $line[0];
	}
	close $fh;
}

# create tree object
my $tree = parse(
	'-format' => 'newick',
	'-file'   => $treefile,
)->first;

# remove unbranched internal nodes, keep tips of interest, serialize
print $tree
	->remove_unbranched_internals
	->keep_tips(\@keep)
	->resolve
	->deroot
	->to_newick;
