#!/opt/rocks/bin/perl -w
#$ -S /opt/rocks/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G,s_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m a
#$ -o /home/sanderm/blast/SGE_JOBS
#$ -v PATH

# For membership in a qdclique we require 
# 	1. One column completely sampled (say, with m taxa)
#	2. All columns >= minTaxa taxa, 
#	3. All columns after the complete column have >= alpha*m taxa


# sends email only on abort; saves job files in subdirectory

# Note the blastall -b option defaults to 250 sequences returned from the database per query. This is probably ok for
# all-all blasting, but not for single query blasting! How stupid.

# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes

# ########## crawlNCBI code for cluster use ###########


use Getopt::Long;
#use strict;
use DBI;
use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;

my $log=0; # set to 1 to log lots of stuff

# ...just a place to store these numbers...program uses the last one...
$tiStart=3803; # Fabaceae

my $human=0;  # human readable output....
my $configFile= "/home/sanderm/blast/pb.conf.bc"; #default
my $mincl=2;
my $mintax=4;
my $alpha=0.5;
my $cigiQuery = "";
my $release ;
my $result = GetOptions ("c=s" => \$configFile,
			 "t=i" => \$tiStart,
			 "mincl=i"=> \$mincl,
			 "mintax=i"=> \$mintax,
			 "alpha=f"=> \$alpha,
			 "magic=s"=> \$magicFile,
			 "release=i"=> \$release  # to override the release from the config file!
			); 


if (!(-e $configFile))
	{ die "Missing config file $configFile\n"; }
if ($human)
	{
	print "Using configuration file $configFile\n";
	print "Run parameters: mincl=$mincl mintax=$mintax alpha=$alpha PB release=$release\n";
	}

my %pbH=%{pb::parseConfig($configFile)};
	my $release=pb::currentGBRelease(); 
die "Couldn't find GB release number\n" if (!defined $release);

my ($saveGI,$saveTI,%tiH);

my $headWorkingDir = $pbH{'HEAD_WORKING_DIR'}; 

my $taskId = $ENV{JOB_ID}; # used to provide unique file names

# Table names with proper release numbers

my $seqTable="seqs" ;
my $featureTable="features" ;
my $nodeTable="nodes" ."\_$release";
my $clusterTable = "clusters_$release";
my $cigiTable = "ci_gi_$release";

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

if (!$magicFile)
	{ push @magic_tis,$tiStart }
else
	{
	open FH, "<$magicFile" or die "No magic file found\n";
	while (<FH>)
		{
		@cols=split;
		push @magic_tis, $cols[0];
		}
	close FH;
	}
# Start the recursion at this node

my $datafile .= "dqbc.$taskId";
open FHOUT, ">$headWorkingDir/$datafile" or die "Unable to open $datafile!\n";
for $magic_ti (@magic_tis)
	{
	#print "Root node for recursion is TI $magic_ti\n";
	if (!exists $nodeH{$magic_ti})
		{
		print "root TI $magic_ti was missing from node hash...probably deleted from NCBI\n" ;
		next;
		}
	my $rootRef=$nodeH{$magic_ti};
	crawlTree($rootRef); # discard return values
	}

# **********************************************************

sub crawlTree

# for the subtree defined by the arg node, return the number of gis and a list of all tis in the clade, and by the way, do the blast stuff!
# Also, store cluster sets and node info in those two respective mysql tables

{
my ($nodeRef)=@_;

die "Invalid or missing node reference passed to crawlTree...probably deleted TI from NCBI\n" if (!defined $nodeRef);

if (0==scalar @{$nodeRef->{DESC}}) { return };  # we never build bicliques at terminal nodes 

my $ti = $nodeRef->{ID};

print "Processing node $ti\n" if $log;

my $currDQBC=0;

my $sql="select clustid,ti_of_gi from $clusterTable,$cigiTable where ti_root=$ti and PI=1 and $clusterTable.cl_type='subtree' and ti=ti_root and ci=clustid";
my $sh = $dbh->prepare($sql);
$sh->execute;
my (%h);
my %clusterSize;
while (my ($clustid,$ti_of_gi) = $sh->fetchrow_array)  # only returns one row (presumably) here and next...
	{
	$h{$clustid}{$ti_of_gi}=1;
	}
$sh->finish;

for $ci (keys %h)
	{
	$clusterSize{$ci} = scalar keys %{$h{$ci}};
	}
my $numFetchedClusters = keys %clusterSize;
my $countDQBC=0;
my $totalCountDQBC=0;
if ($numFetchedClusters >= $mincl) # here's an obvious minimum to proceed
	{
	my @sortedClusters = sort {$clusterSize{$b} <=> $clusterSize{$a} } keys %clusterSize;

	# reduce this to a sorted list of clusters all of which are > mintax 
	my $count=0; # how many bcs we find
	my @minSortedClusters;
	for (@sortedClusters)
		{
		if ($clusterSize{$_} > $mintax)
			{ $minSortedClusters[$count++]=$_; }
		}

	# enumerate the quasi bcs
	for $ci_complete (@minSortedClusters) # each of these will make a dqbiclique using this cluster as its complete cluster
		{
		my @cia = min_alpha($ci_complete,\%clusterSize,$alpha,@minSortedClusters);
		my @ci_complete_taxa = sort {$a <=> $b} keys %{$h{$ci_complete}};
		my $numCompleteTaxa = scalar @ci_complete_taxa;
#		print "$ci_complete |$numCompleteTaxa|@ci_complete_taxa\n";
		my @cia_sort = sort {$a <=> $b} @cia;
		my @ci_keep;
		for $ci ( @cia_sort )
			{
			$intersectionRef = intersect($h{$ci_complete},$h{$ci}); # takes two hash refs as args
			my @intersectionTax = sort {$a <=> $b} keys %{$intersectionRef};
			my $numIntersectTax = scalar @intersectionTax;
			my $minAlpha = $alpha * $numCompleteTaxa;
			if ($numIntersectTax >= $minAlpha && $numIntersectTax >= $mintax)
				{
		#		print "$ci |$numIntersectTax| @intersectionTax\n";
				push @ci_keep,$ci;
				}
			}
		$numClust = @ci_keep;
		next if ($numClust < $mincl);
		next if ($numCompleteTaxa < $mintax);
		++$countDQBC; # don't move
		if ($human) 
			{ 
			print "---------------------------\n";
			print "\nDecisive quasi-biclique at node $ti (max complete taxa = $numCompleteTaxa; num clusters = $numClust; complete ci=$ci_complete)\n\n"; 
			print "[clusters: @ci_keep ]\n";
		# Pretty print the matrix
			$countDens=0;
			for $tx (@ci_complete_taxa)
				{
				print "$tx\t\t";
				for $ci (@ci_keep)
					{
					if (exists $h{$ci}{$tx})
						{ ++$countDens; print "X"}
					else
						{ print "."}
					} 
				print "\n";
				}
			$density = $countDens/($numClust*$numCompleteTaxa);
			print "Density = $density\n"; 
			}

#		for $ci (@ci_keep)
#			{
#			for $tx (@ci_complete_taxa)
#				{
#				if (exists $h{$ci}{$tx})
#					{ print FHOUT "$ti\t$currDQBC\t$ci\t$tx\n" }
#				}
#			}

		print FHOUT "$ti|$currDQBC|@ci_keep|@ci_complete_taxa\n";

		++$currDQBC;

		}  # end enumeration of bicliques
	if ($human)
		{ print "Number of bicliques satisfying specified constraints: $countDQBC\n"; }

	} # end numFetchedClusters
$totalCountDQBC += $countDQBC;
if ($human) {print "Total DQBC at subtree $ti\t = $totalCountDQBC\n";}

# Recurse
for my $descRef (@{$nodeRef->{DESC}})
	{
	crawlTree($descRef);
	}

return;
}

# **********************************************************

sub intersect
{
my ($aRef,$bRef)=@_;
my %h;
for $t (keys %{$bRef})
	{
	if (exists $aRef->{$t})
		{
		$h{$t}=1;
		}
	}
return \%h;
}

sub min_alpha
{
my ($completeCI,$clusterSizeRef,$alpha,@a)=@_;
my $min = $clusterSizeRef->{$completeCI}*$alpha;
#print "Size of clusterSize array:",scalar keys %{$clusterSizeRef},"\n";
#print "CompleteCI:$completeCI, alpha=$alpha, array of cis:@a\n";
my @minSorted;
my $count=0;
for (@a)
	{
	if ($clusterSizeRef->{$_} > $min)
		{
		$minSorted[$count++]=$_;
		}
	}
return @minSorted;
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

