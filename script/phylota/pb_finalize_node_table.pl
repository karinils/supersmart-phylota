# this is a legacy script file from phylota
#!/usr/bin/perl -w

# Assuming a bunch of clades have already been imported into the nodes_XX table, but that deeper
# nodes in the NCBI tree have not yet been added, this script visits the root of each of those clades
# gathers the relevant info and then recurses deeper into the tree toward the root, summing up counts
# of sequences and taxa (but not clusters!) and depositing them at appropriate nodes in the table.

# This script can be run before the model organism script is run because it only deals with seqs and taxa,
# which are not updated in any way by the model org script.

$tiStart=2759; # Eukaryotes

use DBI;
use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  if ($fl =~ /-ti/) {$tiStart = $par;}
  if ($fl =~ /-magic/) {$magicFile = $par;} # file with the root tis of clades that were computed separately on the cluster
  }
die if (!($configFile));

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

# ************************************************************
# Table names with proper release numbers
$nodeTable="nodes" ."\_$release";
# ************************************************************
# mysql initializations 

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



# ************************************************************
# Read the NCBI names, nodes files...

$namesFile="$pbH{GB_TAXONOMY_DIR}/names.dmp";
$nodesFile="$pbH{GB_TAXONOMY_DIR}/nodes.dmp";

open FH, "<$namesFile"; 
while (<FH>)
	{
	($taxid,$name,$unique,$nameClass)=split '\t\|\t';
	if ($nameClass=~/scientific name/)
		{ $sciNameH{$taxid}=$name; }
	if ($nameClass=~/genbank common name/)
		{ $commonNameH{$taxid}=$name; }
	}
close FH;


open FH, "<$nodesFile";
while (<FH>)
	{
	($taxid,$ancid,$rank,@fields)=split '\t\|\t';
	$ancH{$taxid}=$ancid;
	$rankH{$taxid}=$rank;
	if (!exists $nodeH{$ancid})
		{ $nodeH{$ancid}=nodeNew($ancid); } 	
	if (!exists $nodeH{$taxid}) # both these exist tests must be present!
		{ $nodeH{$taxid}=nodeNew($taxid); }
	addChild($nodeH{$ancid},$nodeH{$taxid});
	}
close FH;


open FH, "<$magicFile";
while (<FH>)
	{
	($ti,@others) = split; # ti must be in first column
	$tiReturnNode{$ti}=1;
	}

# Start the recursion at this node
$rootRef=$nodeH{$tiStart};
recurseSum($rootRef);

# **********************************************************
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
sub recurseSum 

{
my ($nodeRef)=@_;
my ($n_node_desc,@descRefs,$numDesc,$i,$ti,$descRef);

$ti = $nodeRef->{ID};
my $H;
if (exists $tiReturnNode{$ti}) 	# just hit a node that is the root of a tree with data
	{
	my $sql="select * from $nodeTable where ti=$ti"; 
	my $sh = $dbh->prepare($sql);
	$sh->execute;
	if ($H = $sh->fetchrow_hashref)  
		{
		return (
			$H->{n_gi_node},
			$H->{n_gi_sub_nonmodel},
			$H->{n_gi_sub_model},
			$H->{n_sp_desc},
			$H->{n_leaf_desc},
			$H->{n_otu_desc}
			)
		}
	else
		{
		print "Node $ti is apparently not present in the phylota database, causing an error here \n";
		return (0,0,0,0,0,0);
		}

	}
else				# presumably this is a node toward the root of the whole tree, not yet having reached a subtree with data
	{


$numDesc =scalar @{$nodeRef->{DESC}};

my ($terminalNode,$rank,$anc,$rankFlag,$comName,$sciName,$rankName);

####### Get information about this node #####
if (0==$numDesc) {$terminalNode=1;} else {$terminalNode=0;} 
$rank=$rankH{$ti};
	# following determines the six basic fields regarding the gi tallies for a node
$anc=$ancH{$ti};
if ($rank eq "genus" || $rank eq "species" || $rank eq "subspecies" || $rank eq "varietas" || $rank eq "subgenus" || $rank eq "forma")
	{ $rankFlag=1; } # used for italics in HTML
else
	{ $rankFlag=0; }
if (exists $commonNameH{$ti})
	{ $comName=$commonNameH{$ti};}
else
	{ $comName="";}
$comName=$dbh->quote($comName);
$sciName=$dbh->quote($sciNameH{$ti});
$rankName=$dbh->quote($rank);

my ($n_gi_node,$n_gi_sub_nonmodel,$n_gi_sub_model,$n_sp_desc,$n_leaf_desc,$n_otu_desc);
$n_gi_node=0;
$n_gi_sub_nonmodel=0;
$n_gi_sub_model=0;
$n_sp_desc=0;
$n_leaf_desc=0;
$n_otu_desc=0;
for $i (0..$numDesc-1)
	{
	$descRef=${$nodeRef->{DESC}}[$i];
	my ($n1,$n2,$n3,$n4,$n5,$n6) = recurseSum($descRef);
	$n_gi_node += $n1;
	$n_gi_sub_nonmodel += $n2;
	$n_gi_sub_model  += $n3;
	$n_sp_desc += $n4;
	$n_leaf_desc += $n5;
	$n_otu_desc += $n6;
	}
$modelFlag=0;
my $s="INSERT INTO $nodeTable VALUES(
		$ti,
		$anc,
		$terminalNode,
		$rankFlag,
		$modelFlag,
		$sciName,
		$comName,
		$rankName,
		$n_gi_node,
		$n_gi_sub_nonmodel,
		$n_gi_sub_model,
		NULL,
		NULL,
		NULL,
		$n_sp_desc,
		NULL,
		$n_leaf_desc,
		$n_otu_desc
		)";
#print "$s\n";
$dbh->do("$s");
	return (
		$n_gi_node,
		$n_gi_sub_nonmodel,
		$n_gi_sub_model,
		$n_sp_desc,
		$n_leaf_desc,
		$n_otu_desc
		)
	}
}


