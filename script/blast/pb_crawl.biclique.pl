#!/opt/rocks/bin/perl -w
#$ -S /opt/rocks/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=8G
#$ -l h_vmem=8G,s_vmem=8G
#$ -M sanderm@email.arizona.edu
#$ -m a
#$ -o /home/sanderm/blast/SGE_JOBS
#$ -v PATH

# NB! I've bumped up the mem above. 3G is plenty for all but primates...

# NB! NO_DESCENT option below!

# LATEST WORKING VERSION OF  BICLIQUE CODE: MAY 1, 2012, UPDATED BY DARREN TO FIX SOME CLUSTER CONFIG STUFF

# ...THERE ARE BICLIQUES THAT OVERCOUNT INDIVIDUAL CLUSTERS, SUCH AS THOSE THAT PUT ITS1 AND ITS1+2+18S INTO A BICLIQUE
# IN INSTANCES WHERE THE TWO HAVE BEEN SEQUENCED FOR SEPARATE ACCESSIONS OF THE SAME SPECIES.


# sends email only on abort; saves job files in subdirectory

# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes

# ########## crawlNCBI code for cluster use ###########

my $NO_DESCENT=1;  # flag to limit computation to root node only.

use Getopt::Long;
use strict;
use DBI;
use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;

my $log=0; # set to 1 to log lots of stuff
# ...just a place to store these numbers...program uses the last one...
my $tiStart=53860; # Coronilla
$tiStart=71240; # eudicots
$tiStart=3880; # Medicago truncatula
$tiStart=163743; # Vicieae
$tiStart=4527; # Oryza
$tiStart=3887; # Pisum
$tiStart=3877; # Medicago
$tiStart=4479; # Poaceae
$tiStart=20400; # Astragalus
$tiStart=163747; # Loteae
$tiStart=3803; # Fabaceae
$tiStart=4747; # Orchidaceae

$|=1; # autoflush


my $biclique_program = "/home/sanderm/bin/bic";
my $configFile= "/home/sanderm/blast/pb.conf.bc"; #default
my $CDSflag=1; 	# default is to use CDS sequences  ; # = 0, use AA seqs instead (not much point really)
my $cigiDataType= 'cds'; # default data type is cds;
my $mincl=2;
my $mintax=4;
my $cigiQuery = "";

######## CHANGE THIS WHEN DONE PLAYING AROUND #########

my $release=0; 



my $result = GetOptions ("c=s" => \$configFile,
                         "t=i"   => \$tiStart,
			 "mincl=i"=> \$mincl,
			 "mintax=i"=> \$mintax,
			 "release=i"=> \$release  # to override the release from the config file!
			); 

#
#  PAY ATTENTION TO THE NEXT LINES !!!!!!!!!!!!
#

if (!(-e $configFile))
	{ die "Missing config file $configFile\n"; }
print "Using configuration file $configFile\n";

my %pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();  # note this overrides the input above!!!!!
die "Couldn't find GB release number\n" if (!defined $release);
my $scriptDir = $pbH{'SCRIPT_DIR'}; 
my $slaveDataDir = $pbH{'SLAVE_DATA_DIR'}; 
my $slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'}; 

my ($saveGI,$saveTI,%tiH);

my $headWorkingDir = $pbH{'HEAD_WORKING_DIR'}; 

my $taskId = $ENV{JOB_ID}; # used to provide unique file names

# will re-use all of these filenames 
my 	$cigiTableFile = "$slaveWorkingDir/rti$tiStart.cigi.id$taskId"; # this will store all the output
my 	$clusterTableFile = "$slaveWorkingDir/rti$tiStart.clusters.id$taskId"; # this will store cluster table entries for this run
my $ndesc="";
if ($NO_DESCENT) {$ndesc="_no_desc"} ; # munge the file name in this special case
my 	$datafile .= "$slaveWorkingDir/bc$tiStart.$taskId";
my 	$out1 = "$datafile.bc$ndesc";
my 	$out2 = "$datafile.bcnum$ndesc";
my 	$out3 = "$datafile.bcfiltered$ndesc";

# Table names with proper release numbers

my $seqTable="seqs" ;
my $featureTable="features" ;
my $nodeTable="nodes" ."\_$release";
my $clusterTable = "clusters_$release";
my $cigiTable = "ci_gi_$release";

# ***********************

logInfo(); # write the log file

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


# Start the recursion at this node

print "Root node for recursion is TI $tiStart\n";
die "root TI $tiStart was missing from node hash...probably deleted from NCBI\n" if (!exists $nodeH{$tiStart});
my $rootRef=$nodeH{$tiStart};
crawlTree($rootRef); # discard return values

 my $s= "cp $out1 $headWorkingDir\n";
 system $s;
 $s= "cp $out2 $headWorkingDir\n";
 system $s;
 $s= "cp $out3 $headWorkingDir\n";
 system $s;
# $s= "cp $datafile $headWorkingDir\n";
# system $s;

# **********************************************************

sub crawlTree

{
my ($nodeRef)=@_;

die "Invalid or missing node reference passed to crawlTree...probably deleted TI from NCBI\n" if (!defined $nodeRef);

if (0==scalar @{$nodeRef->{DESC}}) { return };  # we never build bicliques at terminal nodes 
my $ti = $nodeRef->{ID};

print "Processing node $ti\n" if $log;

my $nQuery = 'subtree';

open FH, ">$datafile" or die "Could not open $datafile for writing\n";

#my $sql="select ti,clustid,ti_of_gi from $clusterTable,$cigiTable where ti_root=$ti and PI=1 and $clusterTable.cl_type='$nQuery' and ti=ti_root and ci=clustid";
my $sql="select ti,clustid,ti_of_gi from $clusterTable,$cigiTable where ti_root=$ti and PI=1 and $cigiTable.cl_type='$nQuery' and ti=ti_root and ci=clustid";
my $sh = $dbh->prepare($sql);
$sh->execute;
my $clustersPresent=0;
while (my ($ti,$clustid,$ti_of_gi) = $sh->fetchrow_array)  # only returns one row (presumably) here and next...
	{
	print FH "$clustid\t$ti_of_gi\n";
	$clustersPresent=1;
	}
$sh->finish;
close FH;

## NB for the future. I should check right here how many PI clusters there are, and if it is less than mincluster, bail, rather than going to trouble of building bicliques!

if ($clustersPresent)
{
my $s = "$biclique_program $datafile $out1 $out2";
print "$s\n";
system "$s";

## Now parse the output from biclique program 

open FH, "<$out1" or die "Can't read from $out1\n";
open FHout, ">>$out3" or die "Can't write to $out3\n";
my $line;
my $bc_id=0;
while (1)
	{
	last unless (defined ($line=<FH>));
	my @clusters = split ' ', $line;
	last unless (defined ($line=<FH>));
	my @taxa = split ' ', $line;
	last unless (defined ($line=<FH>));
	my $ncl=@clusters;
	my $ntx=@taxa;
	if ($ncl >= $mincl && $ntx >= $mintax) 
		{
	#	print FHout "Clusters (node ti$ti): @clusters\n";
	#	print FHout "Taxa (node ti$ti): @taxa\n";
		print FHout "$ti|$bc_id|@clusters|@taxa\n";
		++$bc_id;
		}
	}
close FH;
#close FHout;
}
else # clusters not present...ok to end recursion right now, because if this node has not PI clusters, neither will children!
	{
	print "No clusters were present at node $ti\n";
	return; 
	}


if ($NO_DESCENT) { return };

for my $descRef (@{$nodeRef->{DESC}})
	{
	crawlTree($descRef);
	}

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
if (!defined $dbh) # try to sleep
	{
	my $numSleeps=60;
	warn "My DBI connection failed: sleeping a few times\n";
	while ($numSleeps-- > 0)
		{
		sleep(60);
		$dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});
		last if (defined $dbh);
		}
	}
die "My reconnection failed\n" if (!defined $dbh);
my $AutoReconnect=1;
$dbh->{mysql_auto_reconnect} = $AutoReconnect ? 1 : 0;

return $dbh;
}

sub logInfo
{
my $logFile="$headWorkingDir/rti$tiStart.logfile.id$taskId";
open FH, ">$logFile";

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

