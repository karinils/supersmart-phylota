#!/usr/bin/perl -w

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

use DBI;
use pb;
use Bio::SeqIO;
use Bio::Seq;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

my $sizeCriterionNuc=$pbH{'cutoffLengthNuc'};
my $sizeCriterionFeature=$pbH{'cutoffLengthFeatures'};

die "Cutoff parameters not provided in config files\n" if (!$sizeCriterionNuc || !$sizeCriterionFeature);

$seqTable="seqs";
$featureTable="features";

$dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

createTables();

@files = <$pbH{GB_FLATFILE_DIR}/gb*.seq.gz>;
push @files, <$pbH{GB_CPGENOME_DIR}/NC*.gbk>; # get flatfiles from two directories at this point in history
die ("No files in selected directories\n") if (scalar @files == 0);
add_files($sizeCriterionNuc,$sizeCriterionFeature,@files);


#@files = ("test.remote");
#add_files($sizeCriterion,@files);


#########################

sub add_files
{
my ($sizeCriterionNuc,$sizeCriterionFeature,@files)=@_;

for $file (@files)
{

print "Processing file $file...\n";
if ($file =~ /\.gz$/) # special handing if its a gzipped file
	{
	$in = Bio::SeqIO->new(-file   => "gunzip -c $file |", -format => 'GenBank');
	}
else
	{
	$in = Bio::SeqIO->new(-file   => $file, -format => 'GenBank');
	}


while ( my $seqobj = $in->next_seq() ) 
	{

	eval { 

	$species = $seqobj->species();
	$ti = $species->ncbi_taxid();
	$division  = $seqobj->division();
	@dates=$seqobj->get_dates();		# Gotcha: I'm going to assume there is only one of these dates below...
        $sequence = $seqobj->seq();              # string of sequence
        $acc = $seqobj->accession_number(); # when there, the accession number
        $vers= $seqobj->seq_version();       # when there, the version
        $length= $seqobj->length();            # length
        $def =  $seqobj->desc();             # description
        $gi =  $seqobj->primary_id();       # a unique id for this sequence regardless

	$fmt_date = formatDate($dates[$#dates]); #if there are multiple dates, store the last one!

	$def = $dbh->quote($def);
	$acc = $dbh->quote($acc);
	$vers = $dbh->quote($vers);
	$division = $dbh->quote($division);
	$fmt_date = $dbh->quote($fmt_date);

	if ($length > $sizeCriterionNuc)
		{ undef $sequence; }
	$sequence = $dbh->quote($sequence);
	$s="INSERT INTO $seqTable VALUES($gi,$ti,$acc,$vers,$length,$division,$fmt_date,$release,$def,$sequence)";
	#print "$s\n";
	$dbh->do("$s") or die $dbh->errstr,"\n$s\n";
	

	# then populate the CDS and RNA features, taking care with remotely accessioned features.
	# NB! Bioperl feature->spliced_seq will just return a guess at the length of the sequence, padded with 'N's
	# when the acc number is remote. This is often a bad guess because it is based on the presumption that the
	# ENTIRE feature is remote, when often just a piece of the feature is remote. Go ahead, look at the code...
	#    if( !defined $called_seq ) {
	#	$seqstr .= 'N' x $self->length;  ...here the length is for the feature's location, not the features sublocation
	#	next; ...so for something like join(BC123.1:1-100, 12-200,10000-10100) it might be 10100 minus 12.
	# DO NOT USE feat->length for split sequences at all! unless you want the length of the whole region from min to max


	foreach $feat ( $seqobj->get_SeqFeatures() ) 
		{
		if ($feat->primary_tag =~ /CDS|RNA/)
			{
			my ($tag,$range,$trans,$gene,$transl_table,$codon_start,$gi_feat,$protein_id,$acc,$acc_vers,$product);
			my ($primary_tag,$feature_sequence,$feature_length);
			$range = $feat->location->to_FTstring();
			my $remote=0;
			foreach my $loc ($feat->location->each_Location())
				{
				if ($loc->is_remote())
					{
					$remote=1;
					last;
					}
				}
			# if we don't trap for remote sequences, bad things happen, see above.
			if ($remote == 1) 
				{undef $feature_sequence; undef $feature_length}
			else
				{
				$feature_sequence = $feat->spliced_seq()->seq();
				$feature_length = length $feature_sequence;
				}
                   	foreach $tag ( $feat->get_all_tags() ) 
				{
				$value = join(' ',$feat->get_tag_values($tag));
				if ($tag eq 'protein_id') {($protein_id)=$value};
				if ($tag eq 'gene') {$gene=$value};
				if ($tag eq 'transl_table') {$transl_table=$value};
				if ($tag eq 'codon_start') {$codon_start=$value};
				if ($tag eq 'product') {$product=$value};
				if ($tag eq 'db_xref') {($gi_feat)=($value=~/(\d+)/)};
                   		}
			if ($feat->primary_tag =~ /CDS/)
				{
				next if (!defined $protein_id); # some CDS features are not taken seriously, not translated, etc., so skip
				($acc,$acc_vers)=split '\.',$protein_id;
				}
			# the quote function will return NULL for an undefined value, which is what we want
			# otherwise it takes care of any imbedded quotes
			$primary_tag=$dbh->quote($feat->primary_tag);
			$acc =$dbh->quote($acc);	
			$acc_vers =$dbh->quote($acc_vers);	
			$transl_table =$dbh->quote($transl_table);	
			$codon_start =$dbh->quote($codon_start);	
			$gi_feat =$dbh->quote($gi_feat);	
			$gene=$dbh->quote($gene);
			$range=$dbh->quote($range);
			$product=$dbh->quote($product);

			if (defined $feature_sequence ) 
			    {
			    if ($feature_length > $sizeCriterionFeature)  
					{ undef $feature_sequence }
			    }
			$feature_sequence=$dbh->quote($feature_sequence);
			$feature_length  =$dbh->quote($feature_length);
			$s="INSERT INTO $featureTable VALUES(0,$primary_tag,$gi,$gi_feat,$ti,$acc,$acc_vers,$feature_length,$codon_start,$transl_table,$gene,$product,$range,$feature_sequence)";  # the first 0 is for the autoincrement to work right...thought I could omit it
			#print "$s\n";
			$dbh->do("$s") or die $dbh->errstr,"\n$s\n";

			}
               }
	1;
	} # end eval
or do 
	{ # caught an error in the eval for this sequence
	warn "My code caught a Bioperl or DBI error parsing the 'next sequence'\n";
	print "The mysql string was (which may or may not be relevant!):\n$s\n";
	print "The Bioperl or DBI error message was:\n$@\n";
#die;
	};
#die if ($count++ > 1000);
	} # end while next seq
#die;
} #end file
} #end add files

###########################
sub createTables
{
$dbh->do("drop table $seqTable");
$dbh->do("drop table $featureTable");
$s="create table if not exists $seqTable(
	gi 		BIGINT UNSIGNED ,
	PRIMARY KEY(gi),
	ti 		BIGINT UNSIGNED,
	INDEX(ti), 
	acc 		VARCHAR(12),
	INDEX(acc),
	acc_vers 	SMALLINT UNSIGNED,
	length 		BIGINT UNSIGNED,
	division 	VARCHAR(5),
	acc_date 	DATE,		# when this record was added to database
	gbrel 		SMALLINT UNSIGNED, # the release that we downloaded leading to this new record being added
	def 		TEXT,
	seq 		MEDIUMTEXT
	) ";
$dbh->do("$s");

$s="create table if not exists $featureTable(
	feature_id 	BIGINT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY, # gives us a unique id for features.
	primary_tag	VARCHAR(12),					# the type of data, eg., cds or mRNA
	gi 		BIGINT UNSIGNED,
	INDEX (gi),
	gi_feat 	BIGINT UNSIGNED,
	INDEX(gi_feat),
	ti 		BIGINT UNSIGNED,
	INDEX(ti), 
	acc 		VARCHAR(12),
	acc_vers 	SMALLINT UNSIGNED,
	length	 	BIGINT UNSIGNED,
	codon_start	TINYINT UNSIGNED,
	transl_table	TINYINT UNSIGNED,
	gene		TEXT,
	product		TEXT,
	range		TEXT,
	seq		MEDIUMTEXT
	) ";

$dbh->do("$s");
}

sub formatDate
# convert from bioperl string to standard mysql date
{
my %monthH = (JAN=>1,FEB=>2,MAR=>3,APR=>4,MAY=>5,JUN=>6,JUL=>7,AUG=>8,SEP=>9,OCT=>10,NOV=>11,DEC=>12);
my ($day,$month,$year)=split '\-',$_[0];
return "$year-$monthH{$month}-$day";
}
