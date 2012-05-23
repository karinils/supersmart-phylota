#!/usr/bin/perl

# cgi script to report stats on a cluster SET 
# note that the defline I write is NOT standard NCBI defline (ponder this for local BLUSTER use later!)

# NOTE: THIS SHOULD ALL BE RE-WRITTEN TO TAKE ADVANTAGE OF THE NEW CLUSTER TABLE IN THE DATABASE; HERE
# WE ARE RECOMPUTING EVERYTHING ON THE FLY THAT HAS ALREADY BEEN COMPUTED *EXCEPT* THE DEFLINE OF LONGEST SEQ...

use DBI;
use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$giCutoff=1000;

$cgiGetCluster="$pb::basePB/sql_getcluster.cgi";
$cgiGetConcat="$pb::basePB/sql_getconcat.cgi";
$cgiGetDesc="$pb::basePB/sql_getdesc.cgi";
$cgiGetTrees="$pb::basePB/sql_gettrees.cgi";
$treeViewURL = "$pb::basePB/viewgenetree.cgi";

$seqTable="seqs";
$nodeTable="nodes_$release";
$clusterTable="clusters_$release";

my $sid  = GetDateTime() . int(rand(10000)); 
#my $sid  = int(rand(10000)); 

$treeLink= "<a href=\"$treeViewURL?id=$sid&treename=ti$ti_cl$cl\"/>tree</a>\n";


$qs=$ENV{'QUERY_STRING'};
#$qs="ti=3818&ntype=1&piflag=0&dflag=0&db=172";

@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$tiNode = $val;}
	if ($opt eq "ntype")  # 0 = working on node clusters; 1 = subtree clusters
		{$ntype = $val;}
	if ($opt eq "piflag") 
		{$PIflag = $val;}
	if ($opt eq "db") 
		{$database = $val;}
	}
# mysql database info


$sql="select ti_anc,taxon_name,rank_flag from $nodeTable where ti=$tiNode";


$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$tiNodeName=$rowHRef->{taxon_name};
	$tiNodeRank=$rowHRef->{rank_flag};
	$ti_anc=$rowHRef->{ti_anc};
	}
$sh->finish;


printHeader();
print "<table><tr>";
print "<td>";
print "<a href=\"$cgiGetConcat?ti=$tiNode&piflag=$PIflag&ntype=$ntype&db=$database\" > <img src=\"$pb::basePBhtml/DAV.jpg\" style=\"width: 30px; height: 30px;\"></a>";
print "</td>";
print "<td>";
print "<a href=\"$cgiGetConcat?ti=$tiNode&piflag=$PIflag&ntype=$ntype&db=$database\" >Click here</a> to see taxon by cluster Data Availability Matrix";
print "</td>";
print "</tr></table>";
print "<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">\n";
#print "<tr bgcolor=\"lightblue\"><th>Cluster ID</th><th>Parent cluster</th><th>TaxIDs</th><th>GIs</th><th>L<sub>min</sub></th><th>L<sub>max</sub></th><th>MAD<sup>1</sup></th><th>Q<sup>2</sup></th><th>T<sub>cfi</sub><sup>3</sup></th><th>O/P</th><th>Defline of longest sequence</th><th>Tree<sup>4</sup></th></tr>\n";
print "<tr bgcolor=\"lightblue\"><th>Cluster ID</th><th>Parent cluster</th><th>TaxIDs</th><th>GIs</th><th>L<sub>min</sub></th><th>L<sub>max</sub></th><th>MAD<sup>1</sup></th><th>Q<sup>2</sup></th><th>T<sub>cfi</sub><sup>3</sup></th><th>Defline of longest sequence</th><th>Tree<sup>4</sup></th></tr>\n";

# ...have to specify which type of cluster to retrieve from the cluster table
if ($ntype==0) {$ntypeS = 'node';} else {$ntypeS = 'subtree';}
if ($PIflag){$qPI = "and PI=1";} else {$qPI="";}; # to select just the PI clusters if needed, otherwise get them all
$sql="select ortho,def, ci, n_gi, n_ti, ci_anc, MinLength, MaxLength, MaxAlignDens,Q,strict_res from $seqTable,$clusterTable where ti_root=$tiNode and seqs.gi=$clusterTable.seed_gi $qPI and cl_type='$ntypeS' order by ci ";
$sh = $dbh->prepare($sql);
$sh->execute;

while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$ortho=$rowHRef->{ortho};
	if (defined $ortho)
		{
		if ($ortho==1){$orthoTxt="P";}
		else {$orthoTxt="F";}
		}
	else
		{$orthoTxt="-";}
	$ci=$rowHRef->{ci};
	$numGIs=$rowHRef->{n_gi};
	$numTIs=$rowHRef->{n_ti};
	if (defined($rowHRef->{ci_anc}))
		{ $ci_anc=$rowHRef->{ci_anc}; }
	else
		{$ci_anc=-1;}
	$def=$rowHRef->{def};
	$minL=$rowHRef->{MinLength};
	$maxL=$rowHRef->{MaxLength};
	$maxDensity=$rowHRef->{MaxAlignDens};
	$Q=$rowHRef->{Q};
	$strict_res=$rowHRef->{strict_res};
	$fmMaxDensity=sprintf ("%6.3f",$maxDensity);
	$fmQ=2;
	if (!defined $Q){$fmQ="-";} else { $fmQ=sprintf ("%6.3f",$Q);}
	$fmStrict_res=sprintf ("%6.3f",$strict_res);
	formatRow($ci,$ci_anc,$numTIs,$numGIs,$minL,$maxL,$fmMaxDensity,$fmQ,$fmStrict_res,$orthoTxt,$def);
	}
$sh->finish;


print "</table>";
notes();

print "<br><br><a href=\"$cgiGetDesc?ti=$tiNode&mode=0&db=$database\">Back to taxonomic hierarchy view</a><br>";

if ($database eq "GB157")
	{
	print "<br><br><a href=\"$cgiGetTrees?ti=$tiNode&piflag=$PIflag&db=$database&format=ti\">Display gene trees</a><br>";
	}

print "</html>\n";

sub formatRow
{
my ($cl,$cl_anc,$numTIs,$numGIs,$minL,$maxL,$fmMaxDensity,$fmQ,$fmStrict_res,$orthoTxt,$maxDef)=@_;
my ($fon,$foff);
$fon="<font size=\"-1\" face=\"arial\">";$foff="</font>";
print "<tr bgcolor=\"beige\">";
print "<td align=\"center\"><a href=\"$cgiGetCluster?ti=$tiNode&cl=$cl&ntype=$ntype&db=$database\">$fon$cl$foff</a></td>";
if ($cl_anc==-1)
	{print "<td align=\"center\">$fon-$foff</td>";}
		# notice I force ntype=1 for all references to parent clusters; these should ALWAYS pull out subtree clusters
else
	{print "<td align=\"center\"><a href=\"$cgiGetCluster?ti=$ti_anc&cl=$cl_anc&ntype=1&db=$database\">$fon$cl_anc$foff</a></td>";}
print "<td align=\"right\">$fon$numTIs$foff</td>";
print "<td align=\"right\">$fon$numGIs$foff</td>";
print "<td align=\"right\">$fon$minL$foff</td>";
print "<td align=\"right\">$fon$maxL$foff</td>";
print "<td align=\"center\">$fon$fmMaxDensity$foff</td>";
print "<td align=\"center\">$fon$fmQ$foff</td>";
print "<td align=\"center\">$fon$fmStrict_res$foff</td>";
#print "<td align=\"center\">$fon$orthoTxt$foff</td>";
print "<td align=\"left\">$fon$maxDef$foff</td>";
if ($numTIs>=4 and $numGIs<=$giCutoff)
	{
	$treeLink= "<a href=\"$treeViewURL?id=$sid&treename=ti$tiNode\_cl$cl\"/><img src=\"$pb::basePBicon/LittleTree.gif\" border=0 style=\"width: 15px; height: 20px;\"></a>\n";
	}
else
	{$treeLink="-";}
print "<td align=\"center\">$fon$treeLink$foff</td>";
print "</tr>\n";
}
sub notes
{
$notesText = <<EOF;
&nbsp&nbsp<sup>1</sup>
Maximum Alignment Density<br>
&nbsp&nbsp<sup>2</sup>
"Q" alignment comparison score between default Clustal W and Muscle alignments<br>
&nbsp&nbsp<sup>3</sup>
Level of resolution (consensus fork index) of the strict consensus tree built from the two bootstrap trees from Clustal W and Muscle alignments.<br>
&nbsp&nbsp<sup>4</sup>
Trees are <em>unrooted</em> strict consensus trees of the two majority rule consensus trees constructed by fast bootstrap parsimony algorithm in PAUP* 4.0 using default ClustalW and Muscle alignments. Expect performance to deteriorate with low MAD or Q scores, large number of taxa, and high sequence divergence (largely owing to alignment problems). Only trees for (taxon) phylogenetically informative clusters with fewer than 1000 sequences are generated. 
EOF

print "<tr><td>";
print "<hr>";
print "<font size=\"-1\">";
print $notesText;
print "</font>";
print "</tr></td>";
}
sub printHeader
{
my ($title)=@_;
print "Content-type: text/html\n\n";
if ($tiNodeRank)
	{$tiNodeName="<I>$tiNodeName</I>";}
if ($ntype==0)
	{$s="node $tiNodeName (and only this node)";}
else
	{$s="subtree whose root is $tiNodeName";}
if ($PIflag)
	{$pis=", phylogenetically informative,";}
else
	{$pis="";}
print <<EOF;
<html>\n
<table><tr>
<td><a href="$pb::basePB/pb.cgi"><img src="$pb::basePBicon/PB_logo.gif" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Cluster set at $s </B></font></td>
</tr></table>
<hr>
<head>\n
<title>$title</title>\n
</head>\n
EOF
}
sub GetDateTime {
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset,
                $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();

$YY = 1900+$yearOffset;

$MM = $month;
if($month < 10) {
  $MM =  "0$month";
}

$DD = $dayOfMonth;
if($dayOfMonth<10) {
  $DD = "0$dayOfMonth";
}

$HH = $hour;
if($hour<10) {
   $HH="0$hour";
}

$TT = $minute;
if($minute<10) {
   $TT="0$minute";
}

$SS = $second;
if($second<10) {
   $SS = "0$second";
}


$mydatetime = "$YY$MM$DD$HH$TT$SS";

return $mydatetime;
}

