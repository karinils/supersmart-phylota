# this is a legacy script file from phylota
#!/usr/bin/perl

# cgi script to report stats on a cluster and then allow fasta retrieval
# note that the defline I write is NOT standard NCBI defline (ponder this for local BLUSTER use later!)

use DBI;
use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$cgiGetCluster="$pb::basePB/sql_getcluster.cgi";
$cgiGetConcat="$pb::basePB/sql_getconcat.cgi";
$cgiGetDesc="$pb::basePB/sql_getdesc.cgi";
$getClusterSet="$pb::basePB/sql_getclusterset.cgi";
$getTree="$pb::basePB/sql_gettree.cgi";
$cgiGetTrees="$pb::basePB/sql_gettrees.cgi";
$treeViewURL = "$pb::basePB/viewgenetree.cgi";

$seqTable="seqs";
$nodeTable="nodes_$release";
$clusterTable="clusters_$release";
$cigiTable="ci_gi_$release";

$baseClustal = $pb::baseClustal;
$baseMuscle = $pb::baseMuscle;

# expecting an argument string like: ?ti=3423&ntype=1&piflag=0
# 	ntype=0 means get the node clusters, ntype=1 means get the subtrees clusters
$qs=$ENV{'QUERY_STRING'};

#$qs="ti=27046&cl=0&ntype=1&db=168";

@qargs=split ('&',$qs);
#do "pb_mysql.conf";
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$tiNode = $val;}
	if ($opt eq "ntype") 
		{$ntype = $val;}
	if ($opt eq "cl") 
		{$cluster = $val;}
	if ($opt eq "db") 
		{$database = $val;}
	}

$sortOrder="taxon_name";

if ($ntype==0) 
	{$cl_type="\'node\'";}
else 
	{$cl_type="\'subtree\'";}



$sql="select taxon_name,rank_flag,ti_anc from $nodeTable where ti=$tiNode";
$sh = $dbh->prepare($sql);
$sh->execute;
if ($rowHRef = $sh->fetchrow_hashref)  
	{
	$rowHRef->{taxon_name} =~ s/'//g;
	$taxonRoot=formatTaxonName($rowHRef->{taxon_name},$rowHRef->{rank_flag});
	$ti_anc=$rowHRef->{ti_anc};
	}
$sh->finish;

# Now you should just get some of these fields from the table below rather than recalculating them!
$sql="select ortho,ci_anc from $clusterTable where ti_root=$tiNode and ci=$cluster and cl_type=$cl_type";
$sh = $dbh->prepare($sql);
$sh->execute;
if ($rowHRef = $sh->fetchrow_hashref)  
	{
	$ortho=$rowHRef->{ortho};
	if (defined $ortho)
		{
		if ($ortho==1){$orthoTxt="No";}
		else {$orthoTxt="Yes";}
		}
	else
		{$orthoTxt="-";}
	$ci_anc=$rowHRef->{ci_anc};
        if (defined $ci_anc)
                { $upString="<a href=\"$cgiGetCluster?ti=$ti_anc&cl=$ci_anc&ntype=1&db=$database\">(up to parent cluster)</a>"}
        else
                { $upString=""}

	}
$sh->finish;


#$sql="select $nodeTable.taxon_name,$nodeTable.rank_flag,$seqTable.ti,$seqTable.gi,$seqTable.length,$seqTable.def from $nodeTable,$seqTable,$cigiTable where cl_type=$cl_type and $cigiTable.ti=$tiNode and $cigiTable.clustid=$cluster and $seqTable.gi=$cigiTable.gi and $nodeTable.ti=$seqTable.ti order by $sortOrder";
$sql="select $nodeTable.taxon_name,$nodeTable.rank_flag,$seqTable.ti,$seqTable.gi,$seqTable.length,$seqTable.def from $nodeTable,$seqTable,$cigiTable where cl_type=$cl_type and $cigiTable.ti=$tiNode and $cigiTable.clustid=$cluster and $seqTable.gi=$cigiTable.gi and $nodeTable.ti=$seqTable.ti order by $sortOrder";

print "Content-type: text/html\n\n";
print "<html>";
$sh = $dbh->prepare($sql);
$sh->execute;
$maxL=-1;$minL=10000000;
$sumL=0;
$rowCount=0;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	++$rowCount;
	$gi =$rowHRef->{gi};
	$ti =$rowHRef->{ti};
	$length =$rowHRef->{length};
	$def=$rowHRef->{def};
	$taxon=$rowHRef->{taxon_name};
	$rowHRef->{taxon_name} =~ s/'//g;
	$giH{$gi}=1;
	$tiH{$ti}++;
	$sumL += $length;
	if ($length < $minL) 
		{
		$minL=$length;
		$minDef=$def;
		$minTI=$ti;
		$minGI=$gi;
		}
	if ($length > $maxL) 
		{
		$maxL=$length;
		$maxDef=$def;
		$maxTI=$ti;
		$maxGI=$gi;
		}
	$table[$nr]={%{$rowHRef}}; # copy the hash and store a ref to it
	$table[$nr]{taxon_name}=formatTaxonName($table[$nr]{taxon_name},$table[$nr]{rank_flag});
	$table[$nr]{gi}="<a href=\"http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=nuccore&id=$gi\">$gi</a>";
	++$nr;
	}


$sh->finish;
$dbh->disconnect;
$numTIs = keys %tiH;
$numGIs = keys %giH;
$maxDensity = $sumL/($maxL*$numGIs);
$fmMaxDensity=sprintf ("%6.3f",$maxDensity);

$cgiGetCluster="$pb::basePB/sql_getcluster_fasta.cgi";
print "<table>";
print "<tr><td>";

#print "<font size=\"+2\"><B>$taxonRoot: Cluster $cluster </B><hr></font>\n";

print <<EOF;
<table><tr>
<td><a href=\"$pb::basePB/pb.cgi\"><img src=\"$pb::basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>$taxonRoot: Cluster $cluster </B>$upString</td>
</tr></table>
<hr>
EOF
print "</td></tr>";

print "<tr><td>";
print "<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">\n";

print "<tr><td>Number of sequences (GIs)</td><td>$numGIs</td></tr>\n";
print "<tr><td>Number of distinct taxon IDs (TIs)</td><td>$numTIs</td></tr>\n";
print "<tr><td>Shortest sequence</td><td>$minL nt -- $minDef</td></tr>\n";
print "<tr><td>Longest sequence</td><td>$maxL nt -- $maxDef</td></tr>\n";
print "<tr><td>Maximum alignment density<sup>1</sup></td><td>$fmMaxDensity</td></tr>";
print "<tr><td>Paralogous sequences present?<sup>2</sup></td><td>$orthoTxt</td></tr>";
#print "<tr><td>Maximum alignment density<sup>1</sup></td><td>$fmMaxDensity&nbsp&nbsp<a href=\"$cgiGetCluster?ti=$tiNode&cl=$cluster&ntype=$ntype&db=$database\">(retrieve FASTA file of unaligned sequences)</a>";
print "</td></tr>\n";
print "</table>";

print "</tr></td>";
$notesText = <<EOF;
&nbsp&nbsp<sup>1</sup>The fraction of non-missing nucleotides in an ideal alignment if no gaps had to be introduced.
Low values indicate that cluster sequences are heterogeneous in length, with possibly only local homologies
(for example, if one sequence is a complete mitochondrial genome, and others are single mt genes).
<br>&nbsp&nbsp<sup>2</sup>Assayed via a phylogenetic test of orthology (Sanderson et al., 2003), which checks whether a tree
forcing all sequences from the same species to be a clade is significantly worse than one allowing them to be phylogenetically dispersed. If so, this is presumptive evidence of paralogy, lineage sorting, mistaken identification, or other causes
of such incongruence.
EOF


print "<tr><td>";
print "<font size=\"-1\">";
print $notesText;
print "</font>";
print "</tr></td>";

print <<EOF;
<tr><td>
<hr>
<B>Download sequences as...</B>
<ul>
	<li><a href=\"$cgiGetCluster?ti=$tiNode&cl=$cluster&ntype=$ntype&db=$database\">Unaligned cluster</a> (Fasta format)</li>
	<li><a href=\"$baseClustal/ti$tiNode\_cl$cluster.fa\">Clustal W alignment</a> (Fasta format)</li>
	<li><a href=\"$baseMuscle/ti$tiNode\_cl$cluster.fa\">Muscle alignment</a> (Fasta format)</li>
</ul>
</td></tr>

<tr><td>
<B>Download tree ...</B>
<ul>
	<li>
		Clustal alignment tree <a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=0&format=gi\">(gi#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=0&format=ti\">(ti#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=0&format=giti\">(gi#_ti#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=0&format=names\">('name')</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=0&format=all\">('name_gi#_ti#')</a>
	</li>
	<li>
		Muscle alignment tree <a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=1&format=gi\">(gi#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=1&format=ti\">(ti#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=1&format=giti\">(gi#_ti#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=1&format=names\">('name')</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=1&format=all\">('name_gi#_ti#')</a>
	</li>
	<li>
		Strict consensus tree <a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=2&format=gi\">(gi#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=2&format=ti\">(ti#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=2&format=giti\">(gi#_ti#)</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=2&format=names\">('name')</a>
		<a href=\"$getTree?ti=$tiNode&ci=$cluster&db=$database&t=2&format=all\">('name_gi#_ti#')</a>
	</li>
</ul>
</td></tr>


EOF


$qs="ti=8460&ci=0&t=1&db=GB159&format=names";



# The cluster table proper...
print "<tr><td><br><br>";
# Assign row colors
$colorRowNormal="beige";
$colorRowHeader="lightblue";
for $row (0..$#table)
	{ $rowColor[$row]=$colorRowNormal; }
# some global html stuff (maybe put somewhere better)

	$align="left";
	$border=1;
	$maxCellWidth=750;
	$cellspacing=0;
	$cellpadding=0;
	$altFlag=0;


# ...description of the table layout

@colTitles=("NCBI taxon name","GI","TI","Length","Defline");
@colJustify=("left","left","left","center","left");
@cellWidth=(200,75,75,75,500);
@colOrder=('taxon_name','gi','ti','length','def');

open FHO, ">-";
$FHRef=\*FHO;
printTable($nr,$align,$border,$width,$cellspacing,$colorRowHeader,\@table,$FHRef,\@colTitles,\@rowColor,\@colJustify, \@cellWidth,\@colOrder);
print "</td></tr>";


print "</table>";
print "<br><br><a href=\"$cgiGetDesc?ti=$tiNode&mode=0&db=$database\">Back to taxonomic hierarchy view</a><br>";
print "<a href=\"$pb::basePB/pb.cgi\">Back to Phylota Browser home</a>";
printTailer($FHRef);
close FHO;

# ****************************************************************************
sub printTable

# Takes a reference to a matrix of strings for the elements of the table.

# So far it seems to set default column widths the way I want them without further ado...

{
my ($nr,$align,$border,$width,$cellspacing,$headerbgcolor,$tableRef,$FH,$colTitlesRef,$rowColorRef,$colJustify,$cellWidthRef,$colOrderRef)=@_;
my ($i,$j,$tableWidth);
my ($fon,$foff);
$fon="<font size=\"-1\" face=\"arial\">";$foff="</font>";
$tableWidth=0; # must = total of all columns...
$numCols=@{$cellWidthRef};
for $i (0..$numCols) {$tableWidth+=${$cellWidthRef}[$i];}

print $FH "<body>\n";
print $FH "<table width=\"$tableWidth\" align=\"$align\" border=\"$border\" cellspacing=\"$cellspacing\" cellpadding=\"$cellpadding\" >\n";
print $FH "<tr bgcolor=\"$headerbgcolor\">\n";
for $j (0..$numCols-1)
	{
	print $FH "\t<th width=\"${$cellWidthRef}[$j]\">${$colTitlesRef}[$j]</th>\n"; # table headers for columns
	}	
print $FH "</tr>\n";
for $i (0..$nr-1)
	{
	print $FH "<tr bgcolor=\"${$rowColorRef}[$i]\">\n";
	for $j (0..$numCols-1)
		{ 
		$colKey=$colOrderRef->[$j];
		print $FH "\t<td width=\"${$cellWidthRef}[$j]\" align=\"${$colJustify}[$j]\">$fon${$tableRef}[$i]{$colKey}$foff</td>\n";
		}
	print $FH "</tr>\n";
	}
print $FH "</table>\n";
print $FH "</body>\n";
}

sub formatTaxonName
# puts in italics except for Roman subspecific ranks
{
my ($tn,$rank)=@_;
my ($ret);
if ($rank)
	{
	$tn=~s/var\./\<\/I\>var\.\<I\>/;
	$tn=~s/subsp\./\<\/I\>subsp\.\<I\>/;
	$ret = "<I>" . $tn . "</I>";
	}
else {$ret=$tn;}
return $ret;
}

sub printTailer
{
my ($FH)=@_;
print $FH "</html>\n";
}
sub printHeader
{
my ($title,$FH)=@_;
print "Content-type: text/html\n\n";

print $FH "<html>\n";
print $FH "<head>\n";
print $FH "<title>$title</title>\n";
print $FH "</head>\n";
}

