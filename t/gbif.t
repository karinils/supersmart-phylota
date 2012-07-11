use strict;
use Test::More;
use Bio::Phylo::PhyLoTA::Config;
use IO::File;

# test simple loading
use_ok('Bio::Phylo::PhyLoTA::Service::GbifReader');

# instantiate config object, lookup location of GBIF file
my $config = Bio::Phylo::PhyLoTA::Config->new;
my $file = $config->GBIF_NCBI_FILE;

# check to see if we've downloaded mapping file, skip testing if not
if ( not -f $file ) {
	plan 'skip_all' => "No GBIF file '$file'";
}

# instantiate reader
my $reader = Bio::Phylo::PhyLoTA::Service::GbifReader->new( 'file' => $file );

# start reading
while ( my $species = $reader->next_species ) {
	ok( $species, $species->binomial . ' (' . $species->id . ')' );
}