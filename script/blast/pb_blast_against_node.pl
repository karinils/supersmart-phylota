#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m e

#### Blast a known gi_aa in the database (or maybe an input sequence), against ALL seqs in the subtree of target node
#### This is the amino-acid cluster version ####


# Note the blastall -b option defaults to 250 sequences returned from the database per query. This is probably ok for
# all-all blasting, but not for single query blasting! How stupid.

# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes


use strict;

my $log=0; # set to 1 to log lots of stuff

# ...just a place to store these numbers...program uses the last one...
my $tiStart=53860; # Coronilla
$tiStart=71240; # eudicots
$tiStart=131567; # Cellular organisms
$tiStart=163747; # Loteae
$tiStart=3880; # Medicago truncatula
$tiStart=3398; # Angiosperms
$tiStart=7742; # Vertebrata
$tiStart=2759; # Eukaryotes
$tiStart=163743; # Vicieae
$tiStart=2759; # eukaryotes
$tiStart=6199; # Cestoda
$tiStart=4527; # Oryza
$tiStart=3887; # Pisum
$tiStart=3877; # Medicago
$tiStart=91835; # Eurosid 1
$tiStart=4479; # Poaceae
$tiStart=20400; # Astragalus
$tiStart=163747; # Loteae
$tiStart=3803; # Fabaceae



use POSIX;
use DBI;
use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;

$|=1; # autoflush
my ($gi_query);
my $configFile= "/home/sanderm/blast/pb.conf"; #default
while (my $fl = shift @ARGV)
  {
  my $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  if ($fl =~ /-t/) {$tiStart = $par;}
  if ($fl eq '-gi') {$gi_query = $par;}
  }
if (!(-e $configFile))
	{ die "Missing config file pb.conf\n"; }
my %pbH=%{pb::parseConfig($configFile)};
my $release=pb::currentGBRelease();
die "Couldn't find GB release number\n" if (!defined $release);
my $scriptDir = $pbH{'SCRIPT_DIR'}; 
my $slaveDataDir = $pbH{'SLAVE_DATA_DIR'}; 
my $slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'}; 

my ($saveGI,$saveTI,%tiH);

my $headWorkingDir = $pbH{'HEAD_WORKING_DIR'}; 

my $taskId = $ENV{JOB_ID}; # used to provide unique file names

# will re-use all of these filenames 
my 	$qFile = "$slaveDataDir/rti$tiStart\_q.fa.id$taskId";
my 	$fastaFile = "$slaveDataDir/rti$tiStart.fa.id$taskId";
my 	$lengthFile="$slaveDataDir/rti$tiStart.length.id$taskId";
my 	$blastout = "$slaveWorkingDir/rti$tiStart.BLASTOUT.id$taskId"; 
my 	$blinkin="$slaveWorkingDir/rti$tiStart.BLINKIN.id$taskId"; 
my 	$blinkout="$slaveWorkingDir/rti$tiStart.BLINKOUT.id$taskId"; 
my 	$cigiTableFile = "$slaveWorkingDir/rti$tiStart.cigi.id$taskId"; # this will store all the output
my 	$nodeTableFile = "$slaveWorkingDir/rti$tiStart.nodes.id$taskId"; # this will store node table entries for this run
my 	$clusterTableFile = "$slaveWorkingDir/rti$tiStart.clusters.id$taskId"; # this will store cluster table entries for this run
# ********************** 

my $cutoffClusters=100;
my $cutoffNumGINode=10000; 	# will cluster a node if < this value
my $cutoffNumGISub =35000; 	# will cluster a subtree if < this value (but these will be nonmodel sequences)
my $cutoffLength=25000;

# ***********************
# Table names with proper release numbers

my $seqTable="seqs" ;
my $aaTable="aas" ;
my $nodeTable="nodes" ."\_$release";



# ************************************************************
# Read the NCBI names, nodes files...

my (%sciNameH,%commonNameH);
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/names.dmp"; 
while (<FH>)
	{
	my ($taxid,$name,$unique,$nameClass)=split '\t\|\t';
	if ($nameClass=~/scientific name/)
		{ $sciNameH{$taxid}=$name; }
	if ($nameClass=~/genbank common name/)
		{ $commonNameH{$taxid}=$name; }
	}
close FH;


my (%ancH,%nodeH,%rankH);
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/nodes.dmp";
while (<FH>)
	{
	my ($taxid,$ancid,$rank,@fields)=split '\t\|\t';
	$ancH{$taxid}=$ancid;
	$rankH{$taxid}=$rank;
	if (!exists $nodeH{$ancid})
		{ $nodeH{$ancid}=nodeNew($ancid); } 	
	if (!exists $nodeH{$taxid}) # both these exist tests must be present!
		{ $nodeH{$taxid}=nodeNew($taxid); }
	addChild($nodeH{$ancid},$nodeH{$taxid});
	}
close FH;

my $dbh = db_connect();
 
if ($gi_query) # Query mode
        {
        open FH1, ">$qFile";
        open FH2, ">>$lengthFile"; # append this one value to the length file
        my $sql="select seq_aa,length_aa from aas where gi_aa=$gi_query";
        my $sh =$dbh->prepare($sql);
        $sh->execute;
        my $fastaLen=80;
        if (my ($seq,$len) = $sh->fetchrow_array)  # only returns one row (presumably) here and next...
                {
                print FH1 ">$gi_query\n";
                for (my $i=0;$i<$len;$i+=$fastaLen)
                        {
                        print FH1 substr ($seq,$i,$fastaLen);
                        print FH1 "\n";
                        }
                print FH2 "$gi_query\t$len\n";
#                $query_length = $len; # used later
                }
        else
                {die "Query sequence was not found in database\n"}
        $sh->finish;
        close FH1;
        close FH2;
        }





# Start the recursion at this node

print "Root node for recursion is TI $tiStart\n";
die "root TI $tiStart was missing from node hash...probably deleted from NCBI\n" if (!exists $nodeH{$tiStart});
my $rootRef=$nodeH{$tiStart};
my @tiList=crawlTree($rootRef); # discard return values
blastCluster(@tiList);

my $s= "cp $cigiTableFile $headWorkingDir\n";
system $s;

# **********************************************************

sub crawlTree

# for the subtree defined by the arg node, return the number of gis and a list of all tis in the clade, and by the way, do the blast stuff!
# Also, store cluster sets and node info in those two respective mysql tables

{
my ($nodeRef)=@_;

die "Invalid or missing node reference passed to crawlTree...probably deleted TI from NCBI\n" if (!defined $nodeRef);
my ($terminalNode,$dummy,$modelFlag,$length,@tiList,$numGI,$numGISub,$numGIThis,$numGIThisShort,$numTI,$numDesc,$numGIDesc,$descRef,$ti,$numSeq,$ngi,$nsp,$nodeAlreadyExists);
my ($query, $gi_node, $gi_sub_nonmodel, $gi_sub_model, $numCl_node, $numCl_PI_node, $numCl_sub, $numCl_PI_sub, $nspDesc, $nspModel, $nodeIsClustered, $this_n_clust_node, $this_n_PIclust_node, $this_n_clust_sub, $this_n_PIclust_sub,$nodeWasProcessed);

# ...take care of this NODE
$ti = $nodeRef->{ID};

print "Processing node $ti\n" if $log;

push @tiList,$ti;
$nspDesc=0;
$nspModel=0;
$numGIDesc=0;
$numGIThis=0;
$numGISub=0;
$numCl_node=0;
$numCl_PI_node=0;
$numCl_sub=0;
$numCl_PI_sub=0;

my $n_leaf_desc=0;
my $n_node_desc=0; # "otu's" these are nodes WITH ANY sequences...



if (0==scalar @{$nodeRef->{DESC}}) {$terminalNode=1;} else {$terminalNode=0;} 
my $rank=$rankH{$ti};
my $anc=$ancH{$ti};
my $rankFlag=0;
my ($comName,$sciName,$rankName);
if ($rank eq "genus" || $rank eq "species" || $rank eq "subspecies" || $rank eq "varietas" || $rank eq "subgenus" || $rank eq "forma")
        { $rankFlag=1; } # used for italics in HTML
else
        { $rankFlag=0; }
if (exists $commonNameH{$ti})
        { $comName=$commonNameH{$ti};}
else
        { $comName="";}
# CRAZY TO DO THIS -- FIX AFTER CHECKING BEHAVIOR
# my $dbh = db_connect();
$comName=$dbh->quote($comName);
$sciName=$dbh->quote($sciNameH{$ti});
$rankName=$dbh->quote($rank);
# $dbh->disconnect;



for $descRef (@{$nodeRef->{DESC}})
	{
	my (@tis)=crawlTree($descRef);
	push @tiList,@tis;
	}



return 	(
	@tiList
	);
}


# *************************************************

# for a given list of taxon ids and a seq length cutoff, writes the fasta and length files
# and returns the number of sequences written
# If the taxon list is large, breaks the query into chunks

sub writeSeqs
{
my (@tiList) = @_;
my ($gi,$gi_aa,$length_aa,$ti,$seq,$numTI,$query,$queryShort,$sql,$sh,$rowHRef,$numGI,$numGIShort);
$numTI=@tiList;
if ($numTI == 0)
		{return (0)}; # this happens occasionally if a model node has two model child nodes, for example (I think that's the reason)
my $chunkSize = 50;
my $nChunks = ceil($numTI/$chunkSize);
my $remainder = $numTI % $chunkSize;

my $nSeqs=0;

# my $dbh = db_connect();

open FH, ">$fastaFile";
open FHlen, ">>$lengthFile";
for (my $chunk=0; $chunk < $nChunks; $chunk++)
	{
	my $numElem;
	my $first = $chunk*$chunkSize; 
	if ($chunk == $nChunks -1 ) # i.e., its the last chunk
		{
		if ($remainder==0){$numElem=$chunkSize} # careful of this special case...
		else {$numElem=$remainder}
		}
	else
		{$numElem= $chunkSize;}
	my @smallTiList=@tiList[$first..$first+$numElem-1];

	$queryShort="(";
	for my $i (0..$numElem-2)
			{ $queryShort .= " ti=$smallTiList[$i] OR "; }
	$queryShort .= " ti=$smallTiList[$numElem-1])";
	$sql = "select ti,gi_aa,length_aa,seq_aa from $aaTable,$seqTable where seqs.gi=aas.gi and $queryShort;";
print "$sql\n" if $log;
	$sh = $dbh->prepare($sql);

	if (!$sh)
			{
			warn "Database may have evaporated; try reconnecting..." ;
			db_connect() or warn "Tried reconnecting but failed...\n";
			$sh = $dbh->prepare($sql);
			}
	my $rv=$sh->execute;
	if (!defined $rv)
			{
			warn "Database may have evaporated; trying to reconnect...\n" ;
			db_connect() or warn "Tried reconnecting but failed...\n";
			$sh = $dbh->prepare($sql);
			$sh->execute;
			}
	while ($rowHRef = $sh->fetchrow_hashref)  
			{
			++$nSeqs;
			$gi = $rowHRef->{gi_aa};
			$ti = $rowHRef->{ti};
			$tiH{$gi}=$ti; # setup this global hash for use later
			my $seqLen = $rowHRef->{length_aa};
			$seq = $rowHRef->{seq_aa};
			print FH ">$gi\n$seq\n";
			print FHlen "$gi\t$seqLen\n";
			}
	}
close FH;
close FHlen;
$sh->finish;
# $dbh->disconnect;

if ($nSeqs==1)
	{$saveTI=$ti;$saveGI = $gi;}  # hack to save some crap below for frequent case of one gi in a taxon
else
	{$saveTI=-1;$saveGI = -1;}  
return $nSeqs;
}

# *************************************************
sub  blastCluster
{
	my (@tiList)=@_;

	my ($seqLen,$ti,$numGIcl,$numTI,$numCl,$sql,$sh,$rowHRef,$gi,$def,$seq,$cl,$i);
	my ($clusterID,$s);


	$numTI=@tiList;

	my $numGI=writeSeqs(@tiList);

print "Beginning 1-all blast: ngi=$numGI\tnti=$numTI\n" if ($log);
	if ($numGI==0) 
		{return (0);}

	# Now do the actual all all BLAST, and subsequent processing through blink
	my $blastDir = $pbH{'BLAST_DIR'}; 
	my $formatdbCom =  "$blastDir/bin/formatdb" . 
			" -i $fastaFile" .
			" -p $pbH{'PROTEIN_FLAG'}" .
			" -o $pbH{'PARSE_SEQID_FLAG'}";
	$s= $formatdbCom;
	system ($s) == 0 or die "formatdb failed...\n";
	my $maxBlastOut = $numGI + 1; # IMPORTANT TO SET THIS MAX OUTPUT *ABOVE* THE 250 DEFAULT
	$s =	"$blastDir/bin/blastall" .
				" -i $qFile" .
				" -o $blastout" .
				" -b $maxBlastOut" . 
				" -e $pbH{'BLAST_EXPECT'}" .
				" -F $pbH{'BLAST_DUST'}" . 
				" -p $pbH{'BLAST_PROGRAM'}" .
				" -S $pbH{'BLAST_STRAND'}" .
				" -d $fastaFile" .
				" -m $pbH{'BLAST_OUTPUT_FMT'}";
	#print "$s\n";
	system ($s) == 0 or die "blastall failed...\n";

	$s= "cp $blastout $headWorkingDir\n";
	system $s;
	$s= "$scriptDir/blast2blink.mjs.pl -i $blastout -o $blinkin -t $lengthFile -p $pbH{'OVERLAP_PHI'} -s $pbH{'OVERLAP_SIGMA'} -m $pbH{'OVERLAP_MODE'}\n";
	#print "$s\n";
	system ($s)==0 or die "blast2blink failed...\n";;
	
	# Here just write a cluster table that has a all the hits for a single cluster '0'.
	open FHfcf, ">>$cigiTableFile" or print "Couldn't open final cluster file for append"; 
	open FH, "<$blinkin" or print "Couldn't open BLINKIN file $blinkin for re-reading\n";
	$cl=-1; # in case the next file is empty, we'll return the fact that there are 0 clusters this way
	while (<FH>)
			{
			my ($gi1,$gi2)=split;
			print FHfcf "$tiStart\t0\t'subtree'\t$gi2\t$tiH{$gi2}\n"; 
			}
	close FH;
	close FHfcf;
	$numCl=$cl+1; # assuming cl ids are on 0...n-1
		#  Following removes the sometimes very large BLAST output files...
	if (-e $blastout) {unlink $blastout};

	return;
}


# **********************************************************
sub nodeNew
{
my ($id)=@_;
return {ID=>$id,DESC=>[],NUMSEQ=>0,NUMDESCSEQ=>0,NUMDESCSEQNONMODEL=>0,NUMDESCSPECIES=>0,NUMDESCSEQNODES=>0,NUMDESCSEQNODESNONMODEL=>0,NUMSEQTOTAL=>0,NUMSEQTOTALNONMODEL=>0};
}
# **********************************************************
sub addChild 
{
my ($nodeRef,$childRef)=@_;
push @{ ${$nodeRef}{DESC} },$childRef;
}
# **********************************************************

sub db_connect
{
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});
if (!defined $dbh) # try once to reconnect
	{
	warn "My DBI connection failed: trying to reconnect once\n";
	$dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});
	}
die "My reconnection failed\n" if (!defined $dbh);
my $AutoReconnect=1;
$dbh->{mysql_auto_reconnect} = $AutoReconnect ? 1 : 0;

return $dbh;
}
