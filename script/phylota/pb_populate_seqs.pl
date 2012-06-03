# this is a legacy script file from phylota
#!/usr/bin/perl -w

# Last modified by MJS, 5/21/08

# Reads all gzipped GenBank flat files in the given directory (of form gb*.seq.gz), parses them, and inserts into mysql seq db
# Any sequence longer than $sizeCriterion does NOT get inserted into database, just a NULL. Other fields
# are inserted, however.

# USAGE: ... -c phylota_configuration_file

# MJS: Modified regexs in parser...
# SEE CAVEATS ABOUT THE FLATFILE PARSER BELOW.


# User must supply the input directory and the integer GenBank release number. 
# NOTE. The release number is whatever is stored in that file in the GB_CURRENT_RELEASE directory
# If the gi already exists in the table from a previous release, DBI will balk at re-inserting 
# the same gi in this release. On the other hand, for a truly new sequence, the release number will be stored.

use DBI;
use pb;

$time0 = time();
$sizeCriterion=25000; # If sequence length is strictly greater than this, store information but not the sequence string itself

if ($sizeCriterion > 65535) {$sizeCriterion=65535;} # this is the max size of mysql TEXT object


while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

@files = <$pbH{GB_FLATFILE_DIR}/gb*.seq.gz>;

$seqTable="seqs";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$largeSeqs=0; # I just mean sequences larger than $sizeCiterion, forget the model stuff
$totalBases=0;
$totalAcceptedBases=0;
$totalRecords=0;
$totalAcceptedRecords=0;
print "\n      \t\t  Total  \tAccepted\tTotal\tAccepted\tLarge\n";
print "  File\t\t  Records\tRecords \tBases\tBases   \tSeqs\n";
print "\n--------------------------------------------------------------------------------------------------------------\n";

die ("No files in selected directory\n") if (scalar @files == 0);
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

open (FH1, "gunzip -c $file |") || die "Unable to gunzip $file: $!";

$/="\n//\n";
$bases=0;
$acceptedBases=0;
$records=0;
$acceptedRecords=0;

%monthH = (JAN=>1,FEB=>2,MAR=>3,APR=>4,MAY=>5,JUN=>6,JUL=>7,AUG=>8,SEP=>9,OCT=>10,NOV=>11,DEC=>12);

while (<FH1>) 
  {
  $record = $_;
  ++$records;
#  if ($record =~ /LOCUS\s+\w+\s+(\d+)\sbp.+\b(\w+)\b/)
#if ($record =~ /LOCUS\s+\w+\s+(\d+)\sbp.{4}(\w{1,6})/) # GenBank record respects column positions ...
  if ($record =~ /LOCUS\s+\w+\s+(\d+)\sbp.{4}(\w{1,6}).+([A-Z]{3})\s+(\d+)\-([A-Z]{3})\-(\d{4})/) # GenBank record respects column positions ...
    {
    $length = $1;
    $molType=$2;
    $division=$3;
    $date=$4;
    $month=$5;
    $year=$6;
    $fmt_date = "$year-$monthH{$month}-$date";
    
    $bases+=$length;

    if ($length <= $sizeCriterion)
      {
      ($gid, $tid, $taxon, $def, $keywords, $defline, $sequence) = (&extractGnb($record));
      $quotedDef=$dbh->quote($def); # DBI function takes care of problem with imbedded quotes in INSERT below

      	++$acceptedRecords;
        $acceptedBases += $length;
	$s="INSERT INTO $seqTable VALUES($gid,$tid,$length,\'$division\',\'$fmt_date\',$release,\'$molType\',$quotedDef,\'$sequence\')";
	$dbh->do("$s");
	#if ($dbh->err())
	#	{ print "Offending sql statement:$s\n"; }
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

($fileName)=($file=~/(gb[\w]*\.seq)/);
print "$fileName\t$records\t$acceptedRecords\t$bases\t$acceptedBases\t$largeSeqs\n";

$totalBases+=$bases;
$totalAcceptedBases+=$acceptedBases;
$totalRecords+=$records;
$totalAcceptedRecords+=$acceptedRecords;
$totalLargeSeqs+=$largeSeqs;
}

$dbh->disconnect;
print "\n--------------------------------------------------------------------------------------------------------------\n";
print "Grand total\t$totalRecords\t$totalAcceptedRecords\t$totalBases\t$totalAcceptedBases\t$largeSeqs\n";

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

