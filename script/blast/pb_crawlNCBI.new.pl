#!/opt/rocks/bin/perl -w
#$ -S /opt/rocks/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -l s_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m a
#$ -o /home/sanderm/blast/SGE_JOBS

# Note the blastall -b option defaults to 250 sequences returned from the database per query. This is probably ok for
# all-all blasting, but not for single query blasting! How stupid.

# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes

########### crawlNCBI code for cluster use ###########

#		 MJS January 2009
#	Notes:

#		- Discarding the monitoring of short and long sequences. From now on, only short ones will be processed 
#			and reported. However, because longs may still be in the seq file, we have to exclude them explicitly.

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
$tiStart=3803; # Fabaceae
$tiStart=20400; # Astragalus
$tiStart=57713; # Campanuliids incertae sedis


# NEW AND SIMPLIFIED SCHEMA

# Program reads the NCBI taxonomy dump files, crawls through its tree gathering information
# about the number of sequences and taxa, does all-all blasts at each node that has less than
# a magic number of sequences (to avoid run time explosion), and dumps info into mysql tables.

#  **** Relies on the existence of a seq table in the mysql database. ****

# SOME IMPORTANT TERMINOLOGY:

# Every SEQUENCE is classified by LENGTH 
#		A SHORT sequence is one < $cutoffLength base pairs; a LONG one is the opposite.

# Every NODE in the NCBI taxonomy tree has two elements:
#	1. The 'node' proper, which contains all sequences identified to exactly that node's name
#	2. The 'subtree' associated with that node, which contains all the node's sequences,
#		PLUS all the sequences of all descendant nodes.

# Every NODE is also classified as to whether it is a MODEL organism node. A node is a MODEL organism if either
#	1. It has more than $cutoffNumGI SHORT sequences
#	2. It has more than $cutoffCluster CLUSTERS (which are only constructed based on short sequences)

# Note in the current browser implementation, we display the total number of sequences, respecting whether or not
# they occur in model organisms, but not distinguishing by length.

# A terminal node's sequences are clustered and stored as node clusters.
# For internal nodes, if the node proper has sequences, they are clustered and stored as node clusters. 
# In addition, its node sequences and all its subtree sequences are lumped for clustering and these are
# stored as subtree clusters.

# If a taxon is considered a model organism, all its sequences are EXCLUDED from clustering at older
# nodes in the tree. 
# However, a node's proper sequence count includes model and nonmodel sequences together; the model seqs 
# just might not propogate upward

# usage crawlNCBItree_XXX.pl -r release#  -names names.dmp -nodes nodes.dmp -config Phylota.config
#				-options Phylota.opts -project PhylotaTemp 

# ** Notes on parallel processing this job. **

# It is useful to distribute large subclades of the NCBI tree to different processes. Since the
# program starts from an arbitrary node in the NCBI tree (-ti option), it can run without affecting
# other parts of the tree AS LONG AS THE DIFFERENT PROCESSES TRAVERSE *DISJOINT* SUBTREES. When
# each process finishes it will leave its values for the subtree's root node in the database.

# Later we would then want to traverse the whole tree. As currently programmed, once the crawl visits
# the root node of one of the subtrees that has already been processed, it does not venture into that
# subtree. Instead it gathers the information stored at the subtree's root and recurses back out. It
# does not know at this point the @taxa list for the subtree. This means that when parallelizing this
# whole procedure, you should only process LARGE subtrees that exceed the cutoff number of sequences
# anyway--so the crawl would ignore this node regardless. For example if we do eudicots and monocots 
# separately, both of these clades have too many sequences for there to be clusters at their root nodes
# and we can safely therefore not bother to try to propogate the taxon list deeper in the tree -- we
# can't cluster the next node deeper obviously.

# This makes debugging with small test trees and subtrees problematic of course...

# The crawl will not re-cluster nodes or subtrees that have already been clustered by another process. This
# is indicated by the existence of a nonNULL cluster data in the database

# ** Notes on mysql interaction **

# Sometimes the database is opened but not accessed for hours; this can cause the wait_timeout
# limit on the database to be exceeded, leading to a 'mysql has gone away' type error.

# (DBoss) I didn't make any mysql changes, I just used the mysqladmin tool to query the current settings. The settings got picked up from /etc/my.cnf when starting up mysql using the /etc/init.d/mysqld script. Most Linux distributions will have the /etc/init.d/mysqld script unless mysql is installed from source. If you were starting mysql from the command line, you would issue the following command in order for the settings in /etc/my.cnf to be read.

# /usr/bin/mysqld_safe --defaults-file=/etc/my.cnf

# Now, as of Jan 2009, I am going to test for an active database and reconnect if necessary
# No end of grief doing multiple checks for active databases during recursion.
# Finally seems to work just by connecting and disconnecting each time, but might also work just to have
# mysql timeout disabled.


use POSIX;
use DBI;
use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;

$|=1; # autoflush

my $configFile= "/home/sanderm/blast/pb.conf"; #default
while (my $fl = shift @ARGV)
  {
  my $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  if ($fl =~ /-t/) {$tiStart = $par;}
  }
if (!(-e $configFile))
	{ die "Missing config file pb.conf\n"; }
my %pbH=%{pb::parseConfig($configFile)};
my $release=pb::currentGBRelease();
die "Couldn't find GB release number\n" if (!defined $release);
my $scriptDir = $pbH{'SCRIPT_DIR'}; 
my $slaveDataDir = $pbH{'SLAVE_DATA_DIR'}; 
my $slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'}; 

my $enviro_check_file = "enviro_check.fa";

my ($saveGI,$saveTI,%tiH);

my $headWorkingDir = $pbH{'HEAD_WORKING_DIR'}; 

my $taskId = $ENV{JOB_ID}; # used to provide unique file names

# will re-use all of these filenames 
my 	$fastaFile = "$slaveDataDir/rti$tiStart.fa.id$taskId";
my 	$lengthFile="$slaveDataDir/rti$tiStart.length.id$taskId";
my 	$blastout = "$slaveWorkingDir/rti$tiStart.BLASTOUT.id$taskId"; 
my 	$blinkin="$slaveWorkingDir/rti$tiStart.BLINKIN.id$taskId"; 
my 	$blinkout="$slaveWorkingDir/rti$tiStart.BLINKOUT.id$taskId"; 
my 	$cigiTableFile = "$slaveWorkingDir/rti$tiStart.cigi.id$taskId"; # this will store all the output
my 	$nodeTableFile = "$slaveWorkingDir/rti$tiStart.nodes.id$taskId"; # this will store node table entries for this run
my 	$clusterTableFile = "$slaveWorkingDir/rti$tiStart.clusters.id$taskId"; # this will store cluster table entries for this run
# ********************** 

my $cutoffClusters=$pbH{'cutoffClusters'};
my $cutoffNumGINode=$pbH{'cutoffNumGINode'}; 	# will cluster a node if < this value
my $cutoffNumGISub =$pbH{'cutoffNumGISub'}; 	# will cluster a subtree if < this value (but these will be nonmodel sequences)
my $cutoffLength=$pbH{'cutoffLengthNuc'};

die "Cutoff parameters not provided in config files\n" if (!$cutoffClusters || !$cutoffNumGINode || !$cutoffNumGISub || !$cutoffLength);

# ***********************
my $cigiDataType = 'nuc'; # this value will now be put into the cigi table to indicate type
# ***********************
# Table names with proper release numbers

my $seqTable="seqs" ;
my $nodeTable="nodes" ."\_$release";

# ************************************************************

checkEnvironment();  # check some things on the host compute node to make sure the environment is OK

# ************************************************************
# Read the NCBI names, nodes files...

my $dbh = db_connect();
my (%sciNameH,%commonNameH);
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/names.dmp"; 
while (<FH>)
	{
	my ($taxid,$name,$unique,$nameClass)=split '\t\|\t';
	if ($nameClass=~/scientific name/)
		{ $sciNameH{$taxid}=$dbh->quote($name); }  # might as well add these quotes here, cause will use them in the insert command below
	if ($nameClass=~/genbank common name/)
		{ $commonNameH{$taxid}=$dbh->quote($name); }
	}
close FH;


my (%ancH,%nodeH,%rankH);
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/nodes.dmp";
while (<FH>)
	{
	my ($taxid,$ancid,$rank,@fields)=split '\t\|\t';
	$ancH{$taxid}=$ancid;
	$rankH{$taxid}=$dbh->quote($rank);
	if (!exists $nodeH{$ancid})
		{ $nodeH{$ancid}=nodeNew($ancid); } 	
	if (!exists $nodeH{$taxid}) # both these exist tests must be present!
		{ $nodeH{$taxid}=nodeNew($taxid); }
	addChild($nodeH{$ancid},$nodeH{$taxid});
	}
close FH;
$dbh->disconnect;


logInfo();
# Start the recursion at this node

print "Root node for recursion is TI $tiStart\n";
die "root TI $tiStart was missing from node hash...probably deleted from NCBI\n" if (!exists $nodeH{$tiStart});
my $rootRef=$nodeH{$tiStart};
crawlTree($rootRef); # discard return values

my $s= "cp $cigiTableFile $headWorkingDir\n";
system $s;
$s= "cp $nodeTableFile $headWorkingDir\n";
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
if ($rank eq "'genus'" || $rank eq "'species'" || $rank eq "'subspecies'" || $rank eq "'varietas'" || $rank eq "'subgenus'" || $rank eq "'forma'")
        { $rankFlag=1; } # used for italics in HTML
else
        { $rankFlag=0; }
if (exists $commonNameH{$ti})
        { $comName=$commonNameH{$ti};}
else
        { $comName="''";}
$sciName=$sciNameH{$ti};
$rankName=$rank;


# First, handle the BLAST for the node clusters

$gi_node = countSeqs($cutoffLength,@tiList); # we will continue to exclude seqs >= to this length
$numGI=$gi_node;
if ($numGI >= $cutoffNumGINode) # This is a model organism by definition, don't BLAST
	{
	$modelFlag=1;
	$nspModel=1;
	pop @tiList; # get rid of this node before doing the subtree clustering
	$gi_sub_model=$gi_node;
	$gi_sub_nonmodel=0;
	}
else			# ... BLAST cluster this and note if its a model org by having too many clusters
	{
	($numCl_node)=blastCluster($gi_node,$cutoffLength,$tiStart,$ti,'node',@tiList); 
	if ($numCl_node < $cutoffClusters) # ...and there were few enough clusters to call it a nonmodel org
		{
		$modelFlag=0;
		$gi_sub_nonmodel=$gi_node;
		$gi_sub_model=0;
		}
	else					# ...or a model org
		{
		$modelFlag=1;
		$nspModel=1;
		pop @tiList; # get rid of this node before doing the subtree clustering
		$gi_sub_model=$gi_node;
		$gi_sub_nonmodel=0;
		}
	}

# ...Second, handle the subtree clusters, which include all sequences at this node plus all descendant nodes.
# Done by postorder traversal. We have to get all the descendant's tis to do the clustering for THIS subtree.

for $descRef (@{$nodeRef->{DESC}})
	{
	my ($n1,$n2,$s1,$s2,$s3,$s4,@tis)=crawlTree($descRef);
	push @tiList,@tis;
	$gi_sub_nonmodel+=$n1;
	$gi_sub_model+=$n2;
	$nspDesc+=$s1; 
	$nspModel+=$s2; 
        $n_leaf_desc+=$s3;
        $n_node_desc+=$s4;  # these are OTUs (i.e. nodes with sequences)
	}
	# on this blast cluster we don't need the first two returned values; they've already been set above

if (!$terminalNode) # no sense blasting AGAIN for this node when its terminal!
	{
	$numGI = $gi_sub_nonmodel;
# NB! I can no longer trust
# the @tiList; I've put in a shortcut that zeros out that array when the num seqs is so large that we aren't gonna
# cluster it anyway. Eventually rewrite numGIsql...
	if ($numGI < $cutoffNumGISub) 
		{
		($numCl_sub)=blastCluster($numGI,$cutoffLength,$tiStart,$ti,'subtree',@tiList);
		}
	}


if ($numGI >= $cutoffNumGISub)
	{
	@tiList = (); 	# saves the effort of returning a possibly large array when 
			# it won't be clustered deeper in the tree anyway
	} 


# By placing the following lines *after* storing the value for the node, we enforce the convention that
# taxon counts never include the current node, only the descendants

if ($rank eq "'species'") 
        {$nspDesc=1;}
if ($terminalNode)
        { $n_leaf_desc=1; }
if ($gi_node>0)
        { ++$n_node_desc; }

# All the variables are stored correctly EXCEPT the following does NOT store the two fields for number of PI clusters; 
# just stores a 0 instead. This will have to be fixed in a later mysql script. Clunky to do it here.

# Gotcha! Notice that nodes can't have PI clusters, so I don't need that field, do I?
open FHnodes, ">>$nodeTableFile" or print "Couldn't open node table file for append at ti=$ti"; 
#print FHnodes "$ti\t$anc\t$terminalNode\t$rankFlag\t$modelFlag\t$sciName\t$comName\t$rankName\t$gi_node\t$gi_sub_nonmodel\t$gi_sub_model\t$numCl_node\t$numCl_sub\t$numCl_PI_sub\t$nspDesc\t$nspModel\t$n_leaf_desc\t$n_node_desc\n";
# Notice the \N is written so mysql will read it as a NULL in its load statement (their convention): i.e., I do not keep anything about cluster numbers
print FHnodes "$ti\t$anc\t$terminalNode\t$rankFlag\t$modelFlag\t$sciName\t$comName\t$rankName\t$gi_node\t$gi_sub_nonmodel\t$gi_sub_model\t\\N\t\\N\t\\N\t$nspDesc\t$nspModel\t$n_leaf_desc\t$n_node_desc\t\\N\t\\N\n";
# 12/2010: Added two nulls for the genus fields!
close FHnodes;

return 	(
	$gi_sub_nonmodel,
	$gi_sub_model,
	$nspDesc,
	$nspModel,
        $n_leaf_desc,
        $n_node_desc,
	@tiList
	);
}


# *************************************************

# for a given list of taxon ids and a seq length cutoff, writes the fasta and length files
# and returns the number of sequences written
# If the taxon list is large, breaks the query into chunks

sub writeSeqs
{
my ($lengthCutoff,@tiList) = @_;
my ($gi,$ti,$seq,$numTI,$query,$queryShort,$sql,$sh,$rowHRef,$numGI,$numGIShort);
$numTI=@tiList;
if ($numTI == 0)
		{return (0)}; # this happens occasionally if a model node has two model child nodes, for example (I think that's the reason)
my $chunkSize = 50;
my $nChunks = ceil($numTI/$chunkSize);
my $remainder = $numTI % $chunkSize;

my $nSeqs=0;

my $dbh = db_connect();

open FH, ">$fastaFile" or die "Failed to open fasta file ($fastaFile): maybe target directory was not created on this node ($ENV{HOSTNAME})?\n";
open FHlen, ">$lengthFile" or die "Failed to open length file ($lengthFile)\n";
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

	$queryShort="length<$lengthCutoff AND (";
	for my $i (0..$numElem-2)
			{ $queryShort .= " ti=$smallTiList[$i] OR "; }
	$queryShort .= " ti=$smallTiList[$numElem-1])";
	$sql = "select * from $seqTable where $queryShort;";
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
			$gi = $rowHRef->{gi};
			$ti = $rowHRef->{ti};
			$tiH{$gi}=$ti; # setup this global hash for use later
			my $seqLen = $rowHRef->{length};
			$seq = $rowHRef->{seq};
			print FH ">$gi\n$seq\n";
			print FHlen "$gi\t$seqLen\n";
			}
	}
close FH;
close FHlen;
$sh->finish;
$dbh->disconnect;

if ($nSeqs==1)
	{$saveTI=$ti;$saveGI = $gi;}  # hack to save some crap below for frequent case of one gi in a taxon
else
	{$saveTI=-1;$saveGI = -1;}  
return $nSeqs;
}

# *************************************************
sub  blastCluster
{
	my ($numGI,$cutoffLength,$root_ti,$cur_ti,$cl_type,@tiList)=@_;

	my ($seqLen,$ti,$numGIcl,$numTI,$numCl,$sql,$sh,$rowHRef,$gi,$def,$seq,$cl,$i);
	my ($clusterID,$s);


	$numTI=@tiList;

	writeSeqs($cutoffLength,@tiList);

print "Beginning all-all blast ($cl_type): ti$cur_ti ($sciNameH{$cur_ti})\tngi=$numGI\tnti=$numTI\n" if ($log);
	open FHfcf, ">>$cigiTableFile" or print "Couldn't open final cluster file for append at ti=$cur_ti"; 
	if ($numGI==0) 
		{close FHfcf; return (0);}  # NB. I want to open the cluster file above and close it now, 
						# leaving a possibly empty file...better for management of problematic jobs
	if ($numGI==1) # simple special case of one GI (it happens a lot) .. use values saved at end of fetchSeqs..
		{
#		open FHfcf, ">>$cigiTableFile" or print "Couldn't open final cluster file for append at ti=$cur_ti"; 
		print FHfcf "$cur_ti\t0\t$cl_type\t$saveGI\t$saveTI\t$cigiDataType\n"; # writes to file handled opened before recursion
		close FHfcf;
		$numCl = 1; 
		}
	else 
		{
		# Now do the actual all all BLAST, and subsequent processing through blink



		checkFile($fastaFile, __LINE__);

		my $blastDir = $pbH{'BLAST_DIR'}; 
		my $formatdbCom =  "$blastDir/bin/formatdb" . 
			" -i $fastaFile" .
			" -p $pbH{'PROTEIN_FLAG'}" .
			" -o $pbH{'PARSE_SEQID_FLAG'}";
		$s= $formatdbCom;
		system ($s) == 0 or die "formatdb failed...\n";

		$s =	"$blastDir/bin/blastall" .
				" -i $fastaFile" .
				" -o $blastout" .
				" -e $pbH{'BLAST_EXPECT'}" .
				" -F $pbH{'BLAST_DUST'}" . 
				" -p $pbH{'BLAST_PROGRAM'}" .
				" -S $pbH{'BLAST_STRAND'}" .
				" -d $fastaFile" .
				" -m $pbH{'BLAST_OUTPUT_FMT'}";
		#print "$s\n";
		system ($s) == 0 or die "blastall failed...\n";
		checkFile($blastout, __LINE__);	
		checkFile($lengthFile, __LINE__);	
		$s= "$scriptDir/blast2blink.mjs.pl -i $blastout -o $blinkin -t $lengthFile -p $pbH{'OVERLAP_PHI'} -s $pbH{'OVERLAP_SIGMA'} -m $pbH{'OVERLAP_MODE'}\n";
		#print "$s\n";
		system ($s)==0 or die "blast2blink failed...\n";;
	
		checkFile($blinkin, __LINE__);	
		$s= "$scriptDir/blink -i $blinkin -c > $blinkout\n";
		#print "$s\n";
		system ($s)==0 or die "blink failed...\n";;
	
		checkFile($blinkout, __LINE__);	
#		open FHfcf, ">>$cigiTableFile" or print "Couldn't open final cluster file for append at ti=$cur_ti"; 
		open FH, "<$blinkout" or print "Couldn't open BLINKOUT file $blinkout for re-reading\n";
		$cl=-1; # in case the next file is empty, we'll return the fact that there are 0 clusters this way
		while (<FH>)
			{
			($cl,$gi)=split;
			print FHfcf "$cur_ti\t$cl\t$cl_type\t$gi\t$tiH{$gi}\t$cigiDataType\n"; 
			}
		close FH;
		close FHfcf;
		$numCl=$cl+1; # assuming cl ids are on 0...n-1
		#  Following removes the sometimes very large BLAST output files...
		if (-e $blastout) {unlink $blastout};
	} # end else from above

	return ($numCl);
}
sub checkFile
{
my ($f,$line) = @_;
print "File $f does not exist at line $line\n" if (!(-e $f));
print "File $f is empty at line $line\n" if (-z $f);
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
my $sleeptime=5;
my $numSleeps=60;
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});
if (!defined $dbh) # try once to reconnect
	{
	warn "My DBI connection failed: trying to reconnect once\n";
	$dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});
	}
if (!defined $dbh) # try to sleep
	{
	warn "Still couldn't reconnect...trying sleeping a few times\n";
	while ($numSleeps-- > 0)
		{
		sleep($sleeptime);
		$dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});
		last if (defined $dbh);
		}
	die "My reconnection failed...Giving up!\n" if (!defined $dbh);
	}
my $AutoReconnect=1;
$dbh->{mysql_auto_reconnect} = $AutoReconnect ? 1 : 0;

return $dbh;
}

# *************************************************

# for a given list of taxon ids and a seq length cutoff, 
# returns the number of sequences written
# If the taxon list is large, breaks the query into chunks

sub countSeqs
{
my ($lengthCutoff,@tiList) = @_;
my ($gi,$ti,$seq,$numTI,$query,$queryShort,$sql,$sh,$rowHRef,$numGI,$numGIShort);
$numTI=@tiList;
if ($numTI == 0)
		{return (0)}; # this happens occasionally if a model node has two model child nodes, for example (I think that's the reason)
my $chunkSize = 50;
my $nChunks = ceil($numTI/$chunkSize);
my $remainder = $numTI % $chunkSize;

my $dbh = db_connect();

my $nSeqs=0;

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

	$queryShort="length<$lengthCutoff AND (";
	for my $i (0..$numElem-2)
			{ $queryShort .= " ti=$smallTiList[$i] OR "; }
	$queryShort .= " ti=$smallTiList[$numElem-1])";
	$sql = "select count(*) as ngi from $seqTable where $queryShort;";
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
			$nSeqs += $rowHRef->{ngi};
			}
	}
$sh->finish;
$dbh->disconnect;
return $nSeqs;
}
sub logInfo
{
my $logFile="$headWorkingDir/rti$tiStart.logfile.id$taskId";
open FH, ">$logFile" or print "Failed to open log file ($logFile)\n";

my $now_string = localtime;
print FH "Run date/time  :  $now_string\n";
print FH "Configuration file  :  $configFile\n";
print FH "Data type: $cigiDataType\n";
print FH "Root node of run  :  $tiStart\n";
print FH "************** Configuration File Options ****************\n";
foreach (sort keys %pbH) {print FH "$_  :  $pbH{$_}\n"};
print FH "************** OS and SGE Environment ****************\n";
foreach (sort keys %ENV) {print FH "$_  :  $ENV{$_}\n"};
close FH;
}
sub checkEnvironment
{
# check the local host compute node environment for some things.

my $host = $ENV{HOSTNAME};

# check that parts of key software are in place and can run on this node
# Specificically, tries to use small sample fasta file, $enviro_check_file to format a blast database

die "Missing enviro_check_file\n" if (!(-e $enviro_check_file));

my $blastDir = $pbH{'BLAST_DIR'}; 
my $formatdbCom =  "$blastDir/bin/formatdb -p F -i $enviro_check_file"  ;
my $s= $formatdbCom;
system ($s) == 0 or die "Check of \'$formatdbCom\' FAILED on node $host (error code = $?)\n";

my $slaveDir = $pbH{'SLAVE_DATA_DIR'};
if ( !(-e $slaveDir) )
	{
	die "Check of environment FAILED on node $host: directory $slaveDir does not exist\n";
	}
}
