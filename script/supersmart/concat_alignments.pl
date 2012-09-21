#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger;

# process command line arguments
my ( $list, $verbosity );
GetOptions(
	'list=s'   => \$list,
	'verbose+' => \$verbosity,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# read list of files
my @list;
{
	my $fh;
	
	# may also read from STDIN, this so that we can pipe 
	if ( $list eq '-' ) {
		$fh = \*STDIN;
	}
	else {
		open $fh, '<', $list or die $!;
	}
	
	# slurp contents
	@list = <$fh>;
	chomp @list;
}

# populate supermatrix
my %supermatrix;
my $nchar = 0;
for my $file ( @list ) {

	# read alignment file, return hash where key is NCBI taxon ID,
	# value is aligned sequence
	my %matrix = parse_matrix($file);
	my $matrix_nchar = length $matrix{ ( keys %matrix )[0] };
	
	# concat current data to supermatrix
	for my $row ( keys %matrix ) {	
	
		# if current data has row not yet seen, pad with '?'	
		if ( not exists $supermatrix{$row} ) {
			$supermatrix{$row} = '?' x $nchar;
		}		
		$supermatrix{$row} .= $matrix{$row};
	}
	
	# add missing for supermatrix rows not in matrix
	for my $row ( keys %supermatrix ) {
		if ( not exists $matrix{$row} ) {
			$supermatrix{$row} .= '?' x $matrix_nchar;
		}
	}
	
	# add current matrix's length to overall length
	$nchar += $matrix_nchar;
}

# write output in phylip format
print scalar(keys %supermatrix), ' ', $nchar, "\n";
print $_, ' ', $supermatrix{$_}, "\n" for keys %supermatrix;

# reads in a file, returns a hash keyed on NCBI taxon identifiers, values
# are aligned sequence data
sub parse_matrix {
	my $file = shift;
	my %matrix;
	open my $fh, '<', $file or die $!;
	while(<$fh>) {
		chomp;
		my @fields = split /\t/, $_;
		$matrix{ $fields[0] } = $fields[2];
	}
	return %matrix;
}