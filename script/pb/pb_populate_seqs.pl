#!/usr/bin/perl -w

# NB! October 2, 2010. Added the stuff to read cp genomes AND to read AA sequences to the aas table all as part of this one script
# KNOWN BUG: AA parser does not correctly grab range field joins involving external sequence identifiers (and there may be other 
# similar problems: quite a few ranges enter the database blank YES, see below.


# Reads all gzipped GenBank flat files in the given directory (of form gb*.seq.gz), parses them, and inserts into mysql seq db
# Any sequence longer than $sizeCriterion does NOT get inserted into database, just a NULL. Other fields
# are inserted, however.

# USAGE: ... -c phylota_configuration_file

# MJS: Modified regexs in parser...
# SEE CAVEATS ABOUT THE FLATFILE PARSER BELOW.


# NOTE. The release number is whatever is stored in that file in the GB_CURRENT_RELEASE directory
# If the gi already exists in the table from a previous release, DBI will balk at re-inserting 
# the same gi in this release. On the other hand, for a truly new sequence, the release number will be stored.

use DBI;
use pb;

$time0 = time();
$sizeCriterion=25000; # cutoff for GB records
$sizeCriterionCpGenome=250000; # use a larger cutoff for cp genome sequences

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();


$seqTable="seqs";
$aaTable="aas";

$dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

######### CLUNKY, BUT FIRST ALL THE FLATFILES THEN ADD THE CP GENOME FILES...

@files = <$pbH{GB_FLATFILE_DIR}/gb*.seq.gz>;
die ("No files in selected directory\n") if (scalar @files == 0);
add_files($sizeCriterion,@files);

@files = <$pbH{GB_CPGENOME_DIR}/NC*.gbk>;
die ("No files in selected directory\n") if (scalar @files == 0);
add_files($sizeCriterionCpGenome,@files);

###################################################################################################################

sub add_files
{
my ($sizeCriterion,@files)=@_;

for $file (@files)
{

# [Shelley's old documentation]
# ******************************************************

# script to read a genbank flatfile and store information
# input: 
#	1.  flatfile, genbank format, of all records under consideration 
#	2.  criteria (initialized variables) for retaining records.
# output:
#	1.  flatfile, genbank format, culled to specifications (e.g., by size of seq)
#	2.  fasta file, containing same records as in culled flatfile, with fasta deflines as per NCBI:
#		gi|ginumber|db|accession|locus where db should be replaced by, e.g., gb or emb. 
#	3.  table of gis, tax id numbers, organism names, seq lengths, putative products.  Products are taken from 
#		the keywords field, unless this is empty or contains only ".", in which case it is taken from the 
#		definition field.  
# dependencies:
#	1.  record separator must be // and first line of record must be standard
#	2.  assumes that there are no headers (although if there are, there should be no problem).
#		(Headers are the several lines at the beginning of the genbank flatfiles
#		indicating date of release, etc.)
# NOTE:  this script is creating fasta files with deflines according to the NCBI format, but it is 
#	not possible (as per email with NCBI, 7 Feb 05) to determine the correct db for each accession, 
#	so they are all left as "gb".
# 27 Jul 05:
#	changed table:  added a field to end of line that says "ingroup" or "outgroup" 

# ----- read genbank flatfile, select records to include, make new files --------------------------

if ($file =~ /\.gz$/) # special handing if its a gzipped file
	{
	open (FH1, "gunzip -c $file |") || die "Unable to gunzip $file: $!";
	}
else
	{
	open (FH1, "<$file") || die "Unable to open text file $file: $!";
	}

print "reading $file ...\n";	
$/="\n//\n";

%monthH = (JAN=>1,FEB=>2,MAR=>3,APR=>4,MAY=>5,JUN=>6,JUL=>7,AUG=>8,SEP=>9,OCT=>10,NOV=>11,DEC=>12);

while (<FH1>) 
  {
  $record = $_;
  ++$records;
  if ($record =~ /LOCUS\s+\w+\s+(\d+)\sbp.{4}(\w{1,6}).+([A-Z]{3})\s+(\d+)\-([A-Z]{3})\-(\d{4})/) # GenBank record respects column positions ...
    {
    $length = $1;
    $molType=$2;
    $division=$3;
    $date=$4;
    $month=$5;
    $year=$6;
    $fmt_date = "$year-$monthH{$month}-$date";
    

    if ($length <= $sizeCriterion)
      {
      ($gid, $tid, $taxon, $def, $keywords, $defline, $sequence) = (&extractGnb($record));
      $quotedDef=$dbh->quote($def); # DBI function takes care of problem with imbedded quotes in INSERT below

      	++$acceptedRecords;
        $acceptedBases += $length;
	$s="INSERT INTO $seqTable VALUES($gid,$tid,$length,\'$division\',\'$fmt_date\',$release,\'$molType\',$quotedDef,\'$sequence\')";
	$dbh->do("$s");
      }
    else # sequence is LARGE ,don't retrieve the sequence proper... 
      {
      ($gid, $tid, $taxon, $def, $keywords, $defline)=&extractGnbNoSeq($record);
      $quotedDef=$dbh->quote($def); # DBI function takes care of problem with imbedded quotes in INSERT below
	++$largeSeqs;
	$s="INSERT INTO $seqTable VALUES($gid,$tid,$length,\'$division\',\'$fmt_date\',$release,\'$molType\',$quotedDef,NULL)";
	$dbh->do("$s");
	#if ($dbh->err())
	#	{ print "Offending sql statement:$s\n"; }
	#print "LARGE: gi$gid ti$tid length=$length\n";
      }
    }
  }
close FH1;

}

} #end add files

$dbh->disconnect;

$timeD = (time()-$time0)/60;
print "\n\nTime used:$timeD minutes\n"; 
# *********************************************************************************************************


# ------ subroutine to extract info from genbank format -------------------------
 
sub extractGnb

# if there is no taxon field present, it returns ti=0; this happens!
# NB! (mjs) Occasionally there this fails because there is a rogue word ORIGIN that is used in
# a journal article title or the like; need to get a better way to parse the seqs out! 

# Notice I do not use the defline that Shelley constructed here. I do use the DEFINITION from GB
 
{
my ($gnb)=@_;
my ($ti,$org,$gi,$locus,$defn,$keywds,$vers,$seq,$defline);
($locus) = ($gnb =~ /LOCUS\s+([\w\.]+)\s+/);
($defn) = ($gnb =~ /DEFINITION\s+(.+)ACCESSION/s);
$defn =~ s/\n//g; $defn =~ s/\s+/ /g;
($keywds) = ($gnb =~ /KEYWORDS\s+(.+)SOURCE/s);
$keywds =~ s/\n//g; $keywds =~ s/\s+/ /g;
($vers, $gi) = ($gnb =~ /VERSION\s+(\S+)\s+GI:?(\d+)/);
($org) = ($gnb =~ /ORGANISM\s+(.+)/);
if (!( ($ti) = ($gnb =~ /db_xref=["']taxon:?(\d+)["']/) ) )
	{$ti=0;}
#($seq) = ($gnb =~ /ORIGIN[^\n]*\n(.+)/s);
($seq) = ($gnb =~ /^ORIGIN[^\n]*\n(.+)$/ms); # MJS: my fix for the rare case where word ORIGIN is stuck in title, etc.
chomp $seq; $seq =~ s/\d//g; $seq =~ s/\s//g;
$defline = "gi|$gi|gb|$vers|$locus $defn";			# HACK: gb is in place of the database source.

extractGnbAA($gnb);

return ($gi, $ti, $org, $defn, $keywds, $defline, $seq);
}


sub extractGnbNoSeq

# extract everything but the sequence (useful for long sequences)

{
my ($gnb)=@_;
my ($ti,$org,$gi,$locus,$defn,$keywds,$vers,$seq,$defline);
($locus) = ($gnb =~ /LOCUS\s+([\w\.]+)\s+/);
($defn) = ($gnb =~ /DEFINITION\s+(.+)ACCESSION/s);
$defn =~ s/\n//g; $defn =~ s/\s+/ /g;
($keywds) = ($gnb =~ /KEYWORDS\s+(.+)SOURCE/s);
$keywds =~ s/\n//g; $keywds =~ s/\s+/ /g;
($vers, $gi) = ($gnb =~ /VERSION\s+(\S+)\s+GI:?(\d+)/);
($org) = ($gnb =~ /ORGANISM\s+(.+)/);
if (!( ($ti) = ($gnb =~ /db_xref=["']taxon:?(\d+)["']/) ) )
	{$ti=0;}
$defline = "gi|$gi|gb|$vers|$locus $defn";			# HACK: gb is in place of the database source.

return ($gi, $ti, $org, $defn, $keywds, $defline);
}
 
sub extractGnbAA

 
{
my ($gnb)=@_;
($vers, $gi) = ($gnb =~ /VERSION\s+(\S+)\s+GI:?(\d+)/);
undef @cds;
# There may be several CDS per record, so get an array full
@cds = 		$gnb =~ m%
		^\s{5}CDS  (.+?)  # ? is important to keep to smallest CDS in a record with many CDSs
		/translation="([\w\n\s]+)" # need the \s because of the space prefix on 2nd lines and after
		%gmsx;

# note to self: use the 5-quant to avoid a lot of headaches with spurious matches of the word CDS elsewhere.
# note to self: can change the delim to % but dare not mess with comment on the first line or the switches on the last!

$numCDS = @cds/2;
if ($numCDS > 0)
	{
	for ($ix=0;$ix<$numCDS;$ix++)
		{
		$cds_misc	= $cds[$ix*2];
		$trans		= $cds[$ix*2+1];
		$trans =~ s/\s//g;
		$length_aa = length($trans); # make sure to count aas before adding apostrophes!
		$trans = "\'$trans\'";
		if (  ($range)=($cds_misc=~m%^\s+(\w*\(*[<>,\.\d\s]+\)*)%s)   ) # only took 2 hours to get his right 
## ARGH still not right, does not handle 'complement(join(1..3,5..6...
			{
			$range =~ s/[\n\s]//g;
			$range = "\'$range\'";
			}
		else 
			{$range='NULL'; warn "$gnb\n\n: $cds_misc \n\nno range match\n";}
	
		if ($cds_misc=~m%/db_xref="GI:(\d+)"%) 	{$gi_aa=$1} else {$gi_aa='NULL'};
		if ($cds_misc=~m%/transl_table=(\d+)%) 	{$transl_table=$1} else {$transl_table='NULL'};
		if ($cds_misc=~m%/codon_start=(\d+)%)	{$codon_start=$1} else {$codon_start='NULL'};
		if ($cds_misc=~m%/gene="(\w+)"%)	{$gene="\'$1\'"} else {$gene='NULL'};


		#print "$gi\t$gi_aa\t$transl_table\t$codon_start\t$gene\t$range\t$trans\n";
		#print "$gi\t$gi_aa\t$transl_table\t$codon_start\t$gene\t$range\n$cds_misc\n$trans\n"; 
		++$count_cds;
		$s="INSERT INTO $aaTable VALUES($gi,$gi_aa,$length_aa,$codon_start,$transl_table,$gene,$range,$trans)";
		#print "$s\n";
		$dbh->do("$s");
		}
	}
return;
}
