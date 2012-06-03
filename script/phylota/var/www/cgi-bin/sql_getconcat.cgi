# this is a legacy script file from phylota
#!/usr/bin/perl

# cgi script to get the cluster set for a taxon id and do a concatenation matrix chart

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

$seqTable="seqs";
$nodeTable="nodes_$release";
$clusterTable="clusters_$release";
$cigiTable="ci_gi_$release";


# set up default root node of this tree


# expecting an argument string like: ?ti=3423&ntype=1&piflag=0
#$qs="ti=3423&ntype=1&piflag=0";
# 	ntype=0 means get the node clusters, ntype=1 means get the subtrees clusters
$qs=$ENV{'QUERY_STRING'};


$dflag=0; # default, don't display sequence numbers in each cell
$lim=0; # default, display rows with at least 'lim' clusters 
$limcol=0; # default, display rows with at least 'lim' clusters 
$strict=0;

@qargs=split ('&',$qs);
do "pb_mysql.conf";
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$tiNode = $val;}
	if ($opt eq "ntype") 
		{$ntype = $val;}
	if ($opt eq "piflag") 
		{$PIflag = $val;}
	if ($opt eq "dflag")  # display sequence numbers in each cell?
		{$dflag = $val;}
	if ($opt eq "lim")  # 
		{$lim = $val;}
	if ($opt eq "limcol")  # 
		{$limcol = $val;}
	if ($opt eq "strict")  # display strict clusters or default loose ones?
		{$strict = $val;}
	if ($opt eq "db")  # display strict clusters or default loose ones?
		{$database = $val;}
	}

# mysql database info

if (!$database){ $database="GB157";}

if ($ntype==0)
        {$cl_type="\'node\'";}
else
        {$cl_type="\'subtree\'";}


$sql="select taxon_name,rank_flag from $nodeTable where ti=$tiNode";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$tiNodeName=$rowHRef->{taxon_name};
	$tiNodeRank=$rowHRef->{rank_flag};
	}
$sh->finish;

$sql="select clustid,$seqTable.ti,$seqTable.gi,$nodeTable.taxon_name,rank_flag from $nodeTable,$seqTable,$cigiTable where $cigiTable.ti=$tiNode and $cigiTable.gi=$seqTable.gi and $nodeTable.ti=$seqTable.ti and cl_type=$cl_type";

$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$ci=$rowHRef->{clustid};
	$gi=$rowHRef->{gi};
	$taxon_name=$rowHRef->{taxon_name};
	$ti=$rowHRef->{ti};
	$clusterH{$ci}{$gi}=1;
$clti{$ci}{$ti}++;
	$tiH{$ti}++;
	$tigiH{$gi}=$ti;
	$tiNameH{$ti}=$taxon_name;
	$rankH{$ti}=$rowHRef->{rank_flag};
	}
$sh->finish;


($nr,$nc,$concatArRef)=concat();

$fontOn="<font size=\"-1\" face=\"arial\">";
$fontOff="</font>";

# Assign row colors
$colorRowModelTax="lightgrey";
$colorRowHighlight="lightgrey";
$colorRowNormal="beige";
$colorRowHeader="lightblue";
for $row (0..$nr-2)
	{
	$rowColor[$row]=$colorRowNormal;
#	$rowColor[$row]=$colorRowModelTax if ($model[$row]);
	}
$rowColor[$nr-1]=$colorRowHighlight;
# some global html stuff (maybe put somewhere better)

	$align="left";
	$border=1;
	$maxCellWidth=750;
	$cellspacing=0;
	$cellpadding=0;
	$altFlag=0;


# ...description of the table layout

# Write the html 
$title = "Phylota TaxBrowser Concatenation Table";
open FHO, ">-";
$FHRef=\*FHO;



printHeader($title,$FHRef);
print "<hr>";
print "<table>";
print "<tr><td>";
if ($dflag==0)
	{
	print "Click on cluster ID number to retrieve cluster summary and its sequences. ";
	print "To show numbers of sequences in each cell click <a href=\"$cgiGetConcat?ti=$tiNode&ntype=$ntype&piflag=$PIflag&dflag=1&lim=$lim&limcol=$limcol&strict=$strict&db=$database\">here</a>.";
	}
else
	{
	print "To show presence-absence matrix, click <a href=\"$cgiGetConcat?ti=$tiNode&ntype=$ntype&piflag=$PIflag&dflag=0&lim=$lim&limcol=$limcol&strict=$strict&db=$database\">here</a>.";
	}

print "</td></tr>";
print "<tr><td>";
print "<form action=\"$cgiGetConcat\" method=\"get\" name=\"form1\" id=\"form1\"> To trim matrix to include only taxa where <I>N<sub>cl</sub></I> &ge;  <input type=\"text\" size=\"3\" maxlength=\"20\" name=\"lim\" value=\"$lim\"> "; 
print "and clusters where taxa per cluster &ge;  <input type=\"text\" size=\"3\" maxlength=\"20\" name=\"limcol\" value=\"$limcol\"> <input type=\"submit\" value=\"Trim matrix\">"; 
print "<input type=\"hidden\" name=\"ti\" value=\"$tiNode\">"; # have to use hidden type to send the other vars
print "<input type=\"hidden\" name=\"ntype\" value=\"$ntype\">";
print "<input type=\"hidden\" name=\"piflag\" value=\"$PIflag\">";
print "<input type=\"hidden\" name=\"dflag\" value=\"$dflag\">";
print "<input type=\"hidden\" name=\"db\" value=\"$database\">";
print "</form>";
print "</td></tr>";

print "<tr><td>";
printClusterTable ($nr,$nc,$align,$border,$width,$cellspacing,$colorRowHeader,$concatArRef,$FHRef,\@rowColor);
print "</td></tr>";

#$cgiGetClusterSet="$basePB/sql_getclusterset.cgi" ;
print "<tr><td>";
#print "<br><br><a href=\"$cgiGetDesc?ti=$tiNode&mode=0&db=$database\">Back to sequence diversity table</a>";
print "<br><br><a href=\"$getClusterSet?ti=$tiNode&ntype=$ntype&piflag=$PIflag&dflag=$dflag&db=$database\">Back to cluster set</a>";
print "</td></tr>";
printTailer($FHRef);
print "</table>";
close FHO;



# ****************************************************************************
sub printClusterTable

# Takes a reference to a matrix of strings for the elements of the table.

# So far it seems to set default column widths the way I want them without further ado...

{
my ($nr,$nc,$align,$border,$width,$cellspacing,$headerbgcolor,$tableRef,$FH,$rowColorRef)=@_;
my ($i,$j,$tableWidth,$cell0Width,$cellWidth);
$align="left";
$cell0Width=250;$cellWidthSummary=40;$cellWidthRest=10;
$tableWidth=$cell0Width + $cellWidthSummary+ ($nc-2)*$cellWidthRest; # must = total of all columns...
print $FH "<body>\n";
print $FH "<table width=\"$tableWidth\" align=\"$align\" border=\"$border\" cellspacing=\"$cellspacing\" cellpadding=\"$cellpadding\" >\n";
print $FH "<tr bgcolor=\"$headerbgcolor\">\n";
for $j (0..$nc-1)
		{
		$cellWidth=$cellWidthRest;
		if ($j==0){$cellWidth=$cell0Width;} 
		if ($j==1){$cellWidth=$cellWidthSummary;} 
		print $FH "\t<th width=\"$cellWidth\">${$tableRef}[0][$j] </th>\n"; # table headers for columns
		}	
print $FH "</tr>\n";
for $i (1..$nr-1)
	{
	print $FH "<tr bgcolor=\"${$rowColorRef}[$i]\">\n";
	for $j (0..$nc-1)
		{ 
		$cellWidth=$cellWidthRest;$align="center";
		if ($j==0){$cellWidth=$cell0Width;$align="left";}
		$bgcolor="";
		if ($j==1){$cellWidth=$cellWidthSummary;$bgcolor="bgcolor=\"lightgrey\"";} 
		print $FH "\t<td $bgcolor width=\"$cellWidth\" align=\"$align\">$fontOn${$tableRef}[$i][$j]$fontOff</td>\n";
		}
	print $FH "</tr>\n";
	}
print $FH "</table>\n";
print $FH "</body>\n";
}
# ****************************************************************************

sub printTailer
{
my ($FH)=@_;
print $FH "</html>\n";
}


sub printHeader
{
my ($title,$FH)=@_;
print "Content-type: text/html\n\n";
if ($tiNodeRank)
	{$tiNodeName="<I>$tiNodeName</I>";}
if ($ntype==0)
	{$s="node = $tiNodeName (and only this node)";}
else
	{$s="subtree whose root is $tiNodeName";}


print <<EOF;
<html>\n
<table><tr>
<td><a href=\"$pb::basePB/pb.cgi\"><img src=\"$pb::basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Data availability matrix for cluster set at $s </B></font></td>
</tr></table>
EOF
print $FH "<html>\n";
print $FH "<head>\n";
print $FH "<title>$title</title>\n";
print $FH "</head>\n";
}

sub concat
{
my ($nr,$nc,$numti,$numci,@cisorted,@alltisorted,@clustPIsorted,@taxaPIsorted,@ciSort,@tiSort);
@cisorted = sort {$a <=> $b} keys %clusterH;
@alltisorted=sort {$tiNameH{$a} cmp $tiNameH{$b}} keys %tiH; # changed this from alltiH !!!!!
$numtaxa=@alltisorted;
for $ti (@alltisorted) # initialize this hash of hashes that will act like a matrix for data avail matrix
	{
	for $ci (@cisorted)
		{
#		$concat{$ti}{$ci}="-";
		$concat{$ti}{$ci}="&nbsp";
		}
	} 

for $ci (@cisorted) 
	{
	@gis = keys %{$clusterH{$ci}};
	undef %taxH;
	for $gi (@gis)
		{
		$ti=$tigiH{$gi};
                $taxH{$ti}++; # hash of distinct taxa ids in cluster
		if ($dflag)
			{$concat{$ti}{$ci}=$clti{$ci}{$ti};}
		else
			{$concat{$ti}{$ci}="X";}
		}
        $numTaxa=keys %taxH;
        if ($numTaxa >=4)
                {
                ++$numTaxaPInform;
                $clustPIH{$ci}=1;
                for $ti (keys %taxH) # make a hash of all the taxa that are in some phylogenetically informative cluster
                        {
                        $taxPIH{$ti}=1;
                        }
		}
	}
$concatAr[0][1]="<I>N<sub>cl</sub></I>";

if ($PIflag) # set up sorted 'subarrays' for the phylog inform clusters if needed
	{
	@ciSort=sort {$a <=> $b} keys %clustPIH;
	@tiSort=sort {$tiNameH{$a} cmp $tiNameH{$b}} keys %taxPIH;
	}
else
	{
	@ciSort=@cisorted;
	@tiSort=@alltisorted;
	}

# ...find the row and column totals

for $ci (@ciSort) {$colSumH{$ci}=0;}
for $ti (@tiSort) 
		{
		$rowSum=0;
		for $ci (@ciSort)
			{
			$nSeq=$concat{$ti}{$ci};
			if ($nSeq ne "&nbsp")
				{
				++$rowSum;
				}
			if ($dflag==0)
				{ if ($nSeq ne "&nbsp") {++$colSumH{$ci};} }
			else
				{ if ($nSeq ne "&nbsp") {$colSumH{$ci}+=$nSeq;} }
			}
		$rowSumH{$ti}=$rowSum;
		} 

# ...set up the concat matrix, respecting limits on row/col sums

$nr=1;
for $ti (@tiSort)
	{
	next if ($rowSumH{$ti} < $lim);
	$nc=2;
	for $ci (@ciSort)
		{
		next if ($colSumH{$ci} < $limcol);
		$concatAr[$nr][$nc++]=$concat{$ti}{$ci};

		$concatAr[$nr][1]="<font color=\"green\"><B>$rowSumH{$ti}</B></font>";
		}
	if ($rankH{$ti})
		{$concatAr[$nr++][0]="<I>$tiNameH{$ti}</I>";}
	else
		{$concatAr[$nr++][0]="$tiNameH{$ti}";}
	}


# ...do the first row
$concatAr[0][0]="Taxon";
$nc=2;
for $ci (@ciSort) 
	{
	next if ($colSumH{$ci} < $limcol);
	$concatAr[0][$nc++]=formatGetCluster($tiNode,$ci,$ntype); # write a call to the cgi for get cluster
	}
# ...do the last row
$concatAr[$nr][1]="&nbsp";
if ($dflag==0)
	{$concatAr[$nr][0]="<B>Total taxa per cluster</B>";}
else
	{$concatAr[$nr][0]="<B>Total seqs per cluster</B>";}
$nc=2;
for $ci (@ciSort)
	{
	next if ($colSumH{$ci} < $limcol);
	$concatAr[$nr][$nc++]="<font color=\"green\"><B>$colSumH{$ci}</B></font>";
	}

return ($nr+1,$nc,\@concatAr); # return number of rows, cols, and ref to matrix
}

sub formatGetCluster
{
my ($ti,$cluster,$ntype)=@_;
#$cgiGetCluster="$pb::basePB/sql_getcluster.cgi";
return "<a href=\"$cgiGetCluster?ti=$ti&cl=$cluster&ntype=$ntype&strict=$strict&db=$database\">$cluster</a>";
}
