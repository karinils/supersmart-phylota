#!/usr/bin/perl
#  **************************************************************************************
#  **************************************************************************************
#  ****** !!!!!!!!! DELETES CURRENT SEQ TABLE BEFORE WRITING NEW ONE !!!!!!!!!!**********
#  **************************************************************************************
#  **************************************************************************************
# Reads all gzipped GenBank flat files in the given directory (of form gb*.seq.gz), parses them, and inserts into mysql seq db
# Any sequence longer than $sizeCriterion does NOT get inserted into database, just a NULL. Other fields
# are inserted, however.
# NOTE. The release number is whatever is stored in that file in the GB_CURRENT_RELEASE directory
# If the gi already exists in the table from a previous release, DBI will balk at re-inserting
# the same gi in this release. On the other hand, for a truly new sequence, the release number will be stored.
use strict;
use warnings;
use Bio::Seq;
use Bio::SeqIO;
use Bio::Phylo::PhyLoTA::DBH;
use Bio::Phylo::PhyLoTA::DAO;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use Getopt::Long;

# process command line arguments
my $configFile;
GetOptions( 'configFile=s' => $configFile );

# instantiate config object
my $config = Bio::Phylo::PhyLoTA::Config->new($configFile);

# instantiate sequence getter object
my $sg = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new();

# get config values
my $sizeCriterionNuc     = $config->cutoffLengthNuc;
my $sizeCriterionFeature = $config->cutoffLengthFeatures;
die "Cutoff parameters not provided in config files\n" if ( !$sizeCriterionNuc || !$sizeCriterionFeature );

my $GB_FLATFILE_DIR = $config->GB_FLATFILE_DIR;
my $GB_CPGENOME_DIR = $config->GB_CPGENOME_DIR;

# get flatfiles from two directories at this point in history
my @files = <$GB_FLATFILE_DIR/gb*.seq.gz>;
push @files, <$GB_CPGENOME_DIR/NC*.gbk>;
die("No files in selected directories\n") if ( scalar @files == 0 );

for my $file (@files) {
	print "Processing file $file...\n";
	
	# special handing if its a gzipped file
	my $in;
	if ( $file =~ /\.gz$/ ) {
		$in = Bio::SeqIO->new(
			-file   => "gunzip -c $file |",
			-format => 'GenBank'
		);
	}
	else {
		$in = Bio::SeqIO->new( -file => $file, -format => 'GenBank' );
	}
	while ( my $seqobj = $in->next_seq() ) {
		eval {
			my $daoseq = $sg->store_sequence($seqobj);
			for my $feat ( $seqobj->get_SeqFeatures() ) {
				if ( $feat->primary_tag =~ /CDS|RNA/ ) {
					$sg->store_feature($feat);
				}
			}
		};
		if ( $@ ) {
			warn $@;
		}
	}
}
