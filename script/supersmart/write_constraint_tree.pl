#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::Logger;

# process command line arguments
my ( $treefile, $seqfile, $verbosity );
GetOptions(
	'treefile=s' => \$treefile,
	'seqfile=s'  => \$seqfile,
	'verbose+'   => \$verbosity,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# array of tip names to keep
my @keep;
{
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

# prefix t to tip labels
$tree->visit(sub{
	my $node = shift;
	if ( my $name = $node->get_name ) {
		$node->set_name( "t$name" );
	}
});

# remove unbranched internal nodes, keep tips of interest, serialize
print $tree->remove_unbranched_internals->keep_tips(\@keep)->resolve->to_newick;