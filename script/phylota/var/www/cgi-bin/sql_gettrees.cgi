#!/usr/bin/perl

# Script to format and display trees of a cluster set. Formerly I was trying to call a PERL script that did
# the formatting but Apache doesn't like to return arguments from such scripts using PERL's `...` schema. Hmm.
use DBI;


$basePB    ="http://loco.biosci.arizona.edu/cgi-bin";
$cgiGetCluster="$basePB/sql_getcluster.cgi";
$cgiGetConcat="$basePB/sql_getconcat.cgi";
$cgiGetDesc="$basePB/sql_getdesc.cgi";
$cgiGetTrees="$basePB/sql_gettrees.cgi";
#$formatTreesProgram="$basePB/sql_tree_format.pl";


$qs=$ENV{'QUERY_STRING'};

# To debug set both the following...
#$qs="ti=8460&piflag=1&db=GB157&format=ti";
#$formatTreesProgram="~/PhylotaBrowser/OtherScripts/sql_tree_format.pl";

$format="ti";
@qargs=split ('&',$qs);
do "pb_mysql.conf";
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$tiNode = $val;}
	if ($opt eq "piflag") 
		{$PIflag = $val;}
	if ($opt eq "db") 
		{$database = $val;}
	if ($opt eq "format") 
		{$format = $val;}
	}
# mysql database info


my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",$user,$passwd);

$sql="select ci from cluster_table where ti_root=$tiNode and PI=$PIflag";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$ci=$rowHRef->{ci};
	push @cis,$ci;
	}
$sh->finish;

print "Content-type: text/html\n\n";
print "<html>\n";
print "#nexus<br>begin trees;<br>";
for $ci (@cis)
	{
	$countTree++;
	$fmtTree = treeFormat($tiNode,$ci);
#	$cmd = "$formatTreesProgram -db $database -ci $ci -ti $tiNode -format $format";	
#	$fmtTree = `$cmd`;
#	print "$ci $tiNode <br>";
	if ($fmtTree eq "") 
		{print "[No tree in database for cluster $ci at node $tiNode]\n<br>"}
	else
		{print "tree phylota\_$tiNode\_$ci =  [&U] $fmtTree;\n<br>"}
	}
print "end;<br>";
print "</html>\n";


sub treeFormat

{
my ($tiRoot,$cl)=@_;
my ($sql,$sh,$rowHRef);
$sql="select nj_tree from cluster_table where ti_root=$tiRoot and ci=$cl"; 
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$td =$rowHRef->{nj_tree};
	@gis = ($td=~/(\d+)/g); # pull out all the gis from the TD


	for $gi (@gis) # this may be slower than one long sql query...
		{
		if ($format =~/^Bti^B|giti/i)
			{
			$sqls="select ti from seqs where gi=$gi";
			$shs = $dbh->prepare($sqls);
			$shs->execute;
			while ($rowHRefs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
				{
				$ti = $rowHRefs->{ti};
				$tiH{$gi}=$ti;
				}
			$shs->finish;
			}
		if ($format =~/names|all/i)
			{
			$sqls="select nodes.ti,taxon_name from nodes,seqs where nodes.ti=seqs.ti and gi=$gi";
			$shs = $dbh->prepare($sqls);
			$shs->execute;
			while ($rowHRefs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
				{
				$ti = $rowHRefs->{ti};
				$name = $rowHRefs->{taxon_name};
				$name = $dbh->quote($name);
				$tiH{$gi}=$ti;
				$nameH{$gi}=$name;
				}
			$shs->finish;
			}


		}
	if ($format =~/^Bti^B/i)
		{
		$td =~ s/(\d+)/$tiH{$1}/g;
		}
	if ($format =~/names/i)
		{
		$td =~ s/(\d+)/$nameH{$1}/g;
		}
	if ($format =~/giti/i)
		{
		$td =~ s/(\d+)/gi$1\_ti$tiH{$1}/g;
		}
	if ($format =~/all/i)
		{
		$td =~ s/(\d+)/$nameH{$1}\_gi$1\_ti$tiH{$1}/g;
		}
	return "$td";
	}
$sh->finish;
}
