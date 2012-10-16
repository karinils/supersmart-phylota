#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $verbosity = WARN;
my ( $list, $nexus );
GetOptions(
	'list=s'   => \$list,
	'verbose+' => \$verbosity,
	'nexus'    => \$nexus,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

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

# populate supermatrix
my %supermatrix;
my $nchar = 0;
my %charset;
for my $file ( @list ) {

	# read alignment file, return hash where key is NCBI taxon ID,
	# value is aligned sequence
	my %matrix = parse_matrix($file);
	my $matrix_nchar = length $matrix{ ( keys %matrix )[0] };
	$charset{$file} = [ $nchar + 1 => $nchar + $matrix_nchar ];
	
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

# write results
if ( $nexus ) {
	write_nexus( $nchar, \%supermatrix, \%charset );
}
else {
	write_phylip( $nchar, \%supermatrix );
}

# writes a phylip representation of the supermatrix
sub write_phylip {
	my ( $nchar, $matrix ) = @_;
	my @taxa = sort { $a <=> $b } keys %{ $matrix };
	print scalar(@taxa), ' ', $nchar, "\n";
	print $_, ' ', $matrix->{$_}, "\n" for @taxa;
}

# writes a nexus representation of the supermatrix, with character sets
sub write_nexus {
	my ( $nchar, $matrix, $charset ) = @_;
	my @taxa = sort { $a <=> $b } keys %{ $matrix };
	
	# write taxa block
	print "#NEXUS\nBEGIN TAXA;\n";
	print "\tDIMENSIONS NTAX=".scalar(@taxa).";\n";
	print "\tTAXLABELS\n";
	print "\t\tt$_\n" for @taxa;
	print "\t;\nEND;\n";
	
	# write characters block
	print "BEGIN CHARACTERS;\n";
	print "\tDIMENSIONS NCHAR=${nchar};\n\tFORMAT DATATYPE=DNA GAP=- MISSING=?;\n";
	print "\tMATRIX\n";
	print "\t\tt$_\t", $matrix->{$_}, "\n" for @taxa;
	print "\t;\nEND;\n";
	
	# write sets block
	print "BEGIN SETS;\n";
	for my $set ( sort { $charset->{$a}->[0] <=> $charset->{$b}->[0] } keys %{ $charset } ) {
		my $start = $charset->{$set}->[0];
		my $end   = $charset->{$set}->[1];
		print "\tCHARSET '$set' = ${start}-${end};\n";
	}
	print "END;\n";
}

sub parse_matrix {
	my $file = shift;
	my ( %matrix, $current );
	open my $fh, '<', $file or die $!;
	while(<$fh>) {
		chomp;
		if ( />.*taxon\|(\d+)/ ) {
			$current = $1;
		}
		else {
			s/\s//g;
			$matrix{$current} .= $_;
		}
	}
	return %matrix;
}
