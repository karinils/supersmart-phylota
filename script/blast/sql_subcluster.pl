#!/usr/bin/perl
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m e

# Perform subclustering on an existing phylota cluster using two different strategies:
#	1. Repeat the all-all blast but with different parameters than during the general PB construction
#	2. Blast ONE sequence from the cluster against the whole cluster and pull out the hits.

# For (1): will call blast2blink and blink as usual. User provides the config file which you may set as desired.
# For (2): uses a value theta=$pbH{OVERLAP_THETA} in the config file which specifies the length ratio tolerance to keep the hit,
#		where 0 < theta <= 1. Let Lq be the length of the query sequence and Ls be the length of the substring of the hit
#		starting at the beginning of the first HSP and running through to the end of the last. 
#		We keep the hit iff
#
#				Lq/Ls < theta or Lq/Ls > 1/theta
#
#		If -trim is used, then writes a fasta file with the trimmed sequences and gi ids modified slightly.

# We might want to filter on something slightly different such as the union of the hit lengths, which is done
# in our original blast2blink code, but here we measure the absolute length on the scale of the target sequence.

# Note the blastall -b option defaults to 250 sequences returned from the database per query. This is probably ok for
# all-all blasting, but not for single query blasting! How stupid. I fix this here by setting -b value to the num of seqs + 1

use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;


# DBOSS

$blastResultsMax = 250; # default used for all-all blast; look out if you have a dense cluster and you bump this up
$trimFlag=0; # default
$N_Fraction=1.0; # default is to keep any sequence regardless of how many N's it has
$nquery='subtree';

while ($fl = shift @ARGV)
  {
  if ($fl eq '-o') {$outfilePrefix = shift @ARGV;}
  if ($fl eq '-c') {$configFile = shift @ARGV;}
  if ($fl eq '-r') {$release = shift @ARGV;}
  if ($fl eq '-ti') {$tiNode = shift @ARGV;}
  if ($fl eq '-cl') {$cluster = shift @ARGV;}
  if ($fl eq '-ntype') {$nquery = shift @ARGV;} # default = 'subtree'
  if ($fl eq '-gi') {$gi_query = shift @ARGV;}  # this means we will blast this query gi against the cluster
  if ($fl eq '-N') {$N_Fraction = shift @ARGV;} # discard seqs with more than this fraction of N's in the subject length
  if ($fl eq '-trim') {$trimFlag = 1;}  # report sequences trimmed to their hit boundaries
  }
# Initialize a bunch of locations, etc.

%pbH=%{pb::parseConfig($configFile)};
$database=$release;
$fastaDir = "$pbH{'FASTA_FILE_DIR'}/$release"; 
$scriptDir = $pbH{'SCRIPT_DIR'}; 
$slaveDataDir = $pbH{'SLAVE_DATA_DIR'}; 
$slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'}; 
$headWorkingDir = $pbH{'HEAD_WORKING_DIR'}; 
$tablename="nodes_$release";
$clusterTable = "ci_gi_$release";
my $taskId = $ENV{JOB_ID}; # used to provide unique file names

# Temporary files created with job ids to make them unique to process

$seqFile= "$outfilePrefix.$taskId.fa";
$lengthFile= "$outfilePrefix.$taskId.length";
$blastdb= "blastdb.$taskId";
$outfile .= "$outfilePrefix.$taskId.results";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



# Fetch the sequences and write the temporary fasta file and length file

open FH1, ">$seqFile";
open FH2, ">$lengthFile";

$sql="select seqs.gi,seqs.seq,seqs.length,seqs.ti from seqs,$clusterTable where $clusterTable.ti=$tiNode and $clusterTable.clustid=$cluster and seqs.gi=$clusterTable.gi and cl_type='$nquery'";
$sh = $dbh->prepare($sql);
$sh->execute;
$fastaLen=80;
$countSeqs=0;
while (($gi,$seq,$len,$ti) = $sh->fetchrow_array)  # only returns one row (presumably) here and next...
	{
	print FH1 ">$gi\n";
	for ($i=0;$i<$len;$i+=$fastaLen)
		{
		print FH1 substr ($seq,$i,$fastaLen);
		print FH1 "\n";
		}
	print FH2 "$gi\t$len\n";
	++$countSeqs;
	$seqH{$gi}=$seq; 
	$tiH{$gi}=$ti;
	}
$sh->finish;
close FH1;
close FH2;

if ($gi_query) # Query mode
	{
	$qFile = "$outfilePrefix\_q.$taskId.fa";
	open FH1, ">$qFile";
	open FH2, ">>$lengthFile"; # append this one value to the length file
	$sql="select seq,length from seqs where gi=$gi_query";
	$sh = $dbh->prepare($sql);
	$sh->execute;
	$fastaLen=80;
	if (($seq,$len) = $sh->fetchrow_array)  # only returns one row (presumably) here and next...
		{
		print FH1 ">$gi_query\n";
		for ($i=0;$i<$len;$i+=$fastaLen)
			{
			print FH1 substr ($seq,$i,$fastaLen);
			print FH1 "\n";
			}
		print FH2 "$gi_query\t$len\n";
		$query_length = $len; # used later
		}
	else
		{die "Query sequence was not found in database\n"}
	$sh->finish;
	close FH1;
	}

# Blast code below is written in terms of query and target file of sequences
# For query mode, we're fine with file names; for allall mode we need to make the qFile and tFile the same

$tFile =$seqFile;
if (!$gi_query)
	{ $qFile = $seqFile; }

if (!(-e $qFile  && -e $tFile))
	{
	die ("allallblast: input file(s) are missing\n");
	}


# Run formatdb prior to blast...

$blastDir = $pbH{'BLAST_DIR'}; 
$formatdbCom =  "$blastDir/bin/formatdb" . 
			" -i $tFile" .
			" -p $pbH{'PROTEIN_FLAG'}" .
			" -o $pbH{'PARSE_SEQID_FLAG'}".
			" -n $slaveDataDir/$blastdb";  # write the database files to the slave node with this prefix
print "formatting database with: $formatdbCom\n";
system ($formatdbCom);

# Do the all-by-all blast regardless of startover status from here on
if ($gi_query) { $blastResultsMax = $countSeqs + 1;} # for use in -b option when doing 1-all searches only (keep smaller for all-all)
$blastCom =	"$blastDir/bin/blastall" .
		" -b $blastResultsMax" .
		" -i $qFile" .
		" -o $outfile" .
		" -e $pbH{'BLAST_EXPECT'}" .
		" -F $pbH{'BLAST_DUST'}" . 
		" -p $pbH{'BLAST_PROGRAM'}" .
		" -S $pbH{'BLAST_STRAND'}" .
		" -d $slaveDataDir/$blastdb" .   
		" -m $pbH{'BLAST_OUTPUT_FMT'}";
print "...running Blast NxN\n";
system ($blastCom);
print "$blastCom\n";

if (!$gi_query) # allall mode
	{
	system "$scriptDir/blast2blink.mjs.pl -i $outfile -o $outfile\_BLINKIN -t $lengthFile -p $pbH{'OVERLAP_PHI'} -s $pbH{'OVERLAP_SIGMA'} -m $pbH{'OVERLAP_MODE'}\n";

	system "$scriptDir/blink -i $outfile\_BLINKIN -c > $outfile\_BLINKOUT\n";
	system "cp $outfile\_BLINKOUT $headWorkingDir\n";

	# summarize a bunch of stuff about the cluster set
	open FH1, "<$headWorkingDir/$outfile\_BLINKOUT";
	open FH2, ">$outfile\_ALLALL_SUMMARY";
	while (<FH1>)
		{
		($cl,$gi)=split;
		$countH{$cl}++;
		$len = length $seqH{$gi};
		if (! (exists ($minH{$cl}))) 
			{ $minH{$cl}=$len }
		else
			{
			if ($len < $minH{$cl}) 
				{$minH{$cl}=$len}  
			}
		if (! (exists ($maxH{$cl}))) 
			{ $maxH{$cl}=$len }
		else
			{
			if ($len > $maxH{$cl}) 
				{$maxH{$cl}=$len}  
			}
		}
	close FH1;
	@sortedCl = sort {$countH{$b} <=> $countH{$a}   } keys %countH;
	for $cl (@sortedCl)
		{
		print FH2 "$cl\t$countH{$cl}\t$minH{$cl}\t$maxH{$cl}\n";
		}
	close FH2;
	}

else		# single query mode
		# NB! I use minH and maxH differently here...
	{
	open FH1, "<$outfile";
	while (<FH1>) # for the one query taxon, find the index of the leftmost starting hit and rightmost ending hit
		{
		($queryId, $subjectId, $percIdentity, $alnLength, $mismatchCount, $gapOpenCount, $queryStart, $queryEnd, $subjectStart, $subjectEnd, $eVal, $bitScore) = split(/\t/);
		--$subjectStart;
		--$subjectEnd;   # NCBI uses 1-offset position indexes, unlike PERL
		# be sure to do same for query if it is ever used!!
		if (!exists $minH{$subjectId}) {$minH{$subjectId}=1000000};
		if (!exists $maxH{$subjectId}) {$maxH{$subjectId}=-1000000};
		if ($subjectStart<$minH{$subjectId}){$minH{$subjectId}=$subjectStart};
		if ($subjectEnd>$maxH{$subjectId}){$maxH{$subjectId}=$subjectEnd};
		}
	close FH1;
	$ov = $pbH{OVERLAP_THETA};
	open FH2, ">$outfile\_1QUERY";
	if ($trimFlag)
		{open FH3, ">$outfile\_1QUERY_TRIM"}
	for $gi (keys %minH)
		{
		$subject_length = $maxH{$gi} - $minH{$gi} + 1;
		$lengthRatio = $query_length / $subject_length;
		next if ($lengthRatio < $ov || $lengthRatio > 1/$ov);

		$sq = substr ($seqH{$gi},$minH{$gi},$subject_length);
		$numNs = numN($sq);
		$numNH{$gi}=$numNs;
		$N_cutoff = $N_Fraction*$subject_length;

		next if ($numNs >= $N_cutoff); # skip any sequence entirely if it has too many Ns

		print FH2 "$gi\t$minH{$gi}\t$maxH{$gi}\t$subject_length\t$lengthRatio\t$numNs\n";	
		if ($trimFlag)
			{
			print FH3 ">gi$gi\_trimmed\_$minH{$gi}_$maxH{$gi}\n";
			for ($i=0;$i<$subject_length;$i+=$fastaLen)
				{
				print FH3 substr ($sq,$i,$fastaLen);
				print FH3 "\n";
				}
			}
		}
	if ($trimFlag) {close FH3};
	close FH2;
	}


# Return the number of N's or n's in a sequence
sub numN
{
my ($s) = @_;
my $count=0;
$count++ while $s =~ /[N|n]/g;
return $count;
}
