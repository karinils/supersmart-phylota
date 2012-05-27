use Test::More 'no_plan';
use Net::Ping;

BEGIN { use_ok('Bio::Phylo::PhyLoTA::Config'); }
my $config = new_ok('Bio::Phylo::PhyLoTA::Config');

# verify these directories exist
my @dirs = qw(
	GB_FLATFILE_DIR
	GB_TAXONOMY_DIR
	FASTA_FILE_DIR
	SLAVE_DATA_DIR
	SLAVE_WORKING_DIR
	SCRIPT_DIR
	HEAD_WORKING_DIR
	BLAST_DIR
);
for my $dir ( @dirs ) {
	ok( $config->$dir, "directory $dir is defined" );
	ok( -d $config->$dir, "directory $dir exists" );
}

# verify these files exist
my @files = qw(
	GB_RELNUM_FILE
	GB_RELNUM_DATE_FILE
	BLAST2BLINKSIMPLE
	BLAST2BLINKOVERLAP
);
for my $file ( @files ) {
	ok( $config->$file, "file $file is defined" );
	ok( -f $config->$file, "file $file exists" );
}

# verify these servers are reachable
my @servers = qw(HOST SERVER);
my $p = Net::Ping->new;
for my $server ( @servers ) {
	ok( $config->$server, "server $server is defined" );
	ok( $p->ping($config->$server), "server $server is reachable" );
}