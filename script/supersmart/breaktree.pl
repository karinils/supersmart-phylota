#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse_tree';
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $cutoff    = 0.85; # bootstrap threshold
my $minsize   = 10; # minimum clade size
my $verbosity = WARN;
my $format    = 'newick',
my $uselabels;
my $infile;
GetOptions(
	'verbose+'  => \$verbosity,
	'minsize=i' => \$minsize,
	'cutoff=f'  => \$cutoff,
	'infile=s'  => \$infile,
	'format=s'  => \$format,
	'uselabels' => \$uselabels,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# parse tree
my $tree = parse_tree(
	'-format' => $format,
	'-file'   => $infile,
	'-as_project' => 1,
);

$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;

		# start caching monophyletic list that grows in post-order
		$node->set_generic( 'tips' => [ $node->get_name ] );
	},
	'-post' => sub {
		my $node = shift;
		my @children = @{ $node->get_children };

		# node is internal
		if ( @children ) {

			# get tip labels assembled so far
			my @tips = map { @{ $_->get_generic('tips') } } @children;

			# clear caches of children
			$_->set_generic for @children;

			# fetch bootstrap value from node name or branch length
			my $bs = $uselabels ? $node->get_name : $node->get_branch_length;

			# clade is breakable
			if ( $node->is_root or ( $bs >= $cutoff and scalar @tips >= $minsize ) ) {
				my $name = $node->get_internal_name;
				print $name, "\t", $_, "\n" for @tips;

				# reduce cache to just the leftmost and rightmost
				@tips = ( $tips[0], $tips[-1] );
			}

			# carry cache downward
			$node->set_generic( 'tips' => \@tips );
		}
	}
);
