#!/usr/bin/perl -w

# Reads all gzipped GenBank flat files in the given directory (of form gb*.seq.gz), parses them, finds the CDS translations
# and inserts into mysql seq db
#
# Any CDS record whose DNA seq is longer than $sizeCriterion does NOT get inserted into database, just a NULL. Other fields
# are inserted, however.

# USAGE: ... -c phylota_configuration_file

# MJS: Modified regexs in parser...
# SEE CAVEATS ABOUT THE FLATFILE PARSER BELOW.


# NOTE. The release number is whatever is stored in that file in the GB_CURRENT_RELEASE directory
# If the gi already exists in the table from a previous release, DBI will balk at re-inserting 
# the same gi in this release. On the other hand, for a truly new sequence, the release number will be stored.

use DBI;
use pb;

$seqTable="aas";

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

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

@files = <$pbH{GB_FLATFILE_DIR}/gbpln*.seq.gz>;
#@files = <testgbbreak.seq.gz>;

die ("No files in selected directory\n") if (scalar @files == 0);

$countFiles=0;
for $file (@files)
{
#die if ($countFiles++ > 0);
$count_cds=0;

# [Shelley's old documentation: see dna population script]

open (FH1, "gunzip -c $file |") || die "Unable to gunzip $file: $!";

$/="\n//\n";


while (<FH1>) 
  {
  $record = $_;
  ++$records;
  if ($record =~ /LOCUS\s+\w+\s+(\d+)\sbp.{4}(\w{1,6}).+([A-Z]{3})\s+(\d+)\-([A-Z]{3})\-(\d{4})/) # GenBank record respects column positions ...
    {
    $length = $1;

    if ($length >  $sizeCriterion && $length<250000)
      {
	($gi,$numCDS) = extractGnb($record); 
	if ($numCDS>0)
		{print "$file:$gi:\t$length\t$numCDS\n";}
	$totalCDS+=$numCDS;
	}
    }
  }
close FH1;



}
print "Total CDS found = $totalCDS\n";

$dbh->disconnect;

$timeD = (time()-$time0)/60;
print "\n\nTime used:$timeD minutes\n"; 

# *********************************************************************************************************


# ------ subroutine to extract info from genbank format -------------------------
 
sub extractGnb

 
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


return ($gi,$numCDS);
}

