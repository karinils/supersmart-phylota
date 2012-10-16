#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::PhyLoTA::DBH;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $verbosity, $field, $line ) = ( WARN, "\t", "\n" );
my ( $infile, $table );
GetOptions(
	'infile=s' => \$infile,
	'table=s'  => \$table,
	'field=s'  => \$field,
	'line=s'   => \$line,
	'verbose+' => \$verbosity,
);

# instantiate helper objects
my $dbh = Bio::Phylo::PhyLoTA::DBH->new;
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# set the line separator
local $/ = $line;
$log->debug("set line separator to $line");

# create the file handle
open my $fh, '<', $infile or die $!;
$log->debug("going to read from file $infile");

# this will be the prepared statement
my $insert_handle;

# iterate over lines
while(<$fh>) {
	chomp;
	$log->debug("LINE: '$_'");
	
	# split line over separator
	my @fields = split /$field/;
	$log->debug("fields are @fields");
	
	# create the handle the first time
	if ( not $insert_handle ) {
		my @placeholders;
		push @placeholders, '?' for 1 .. @fields;
		my $template   = join ',', @placeholders;
		my $statement  = "INSERT INTO $table VALUES ($template);";
		$insert_handle = $dbh->prepare_cached($statement);
		$log->info("created insert handle '$statement'");
	}
	
	# do the insertion
	if ( $insert_handle->execute(@fields) ) {
		$log->debug("inserted @fields");
	}
	else {
		$log->warn("problem inserting @fields");
	}
}