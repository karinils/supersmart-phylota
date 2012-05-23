#!/usr/bin/perl

# Programmed by Duhong Chen initially; modified by MJS

use IO::Socket;
use CGI ':standard';
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);

$giCutoff=1000; # don't try to draw trees larger than this
$basePBicon="http://loco.biosci.arizona.edu/icons";
$basePBcgi="http://loco.biosci.arizona.edu/cgi-bin";

$remote_host = "loco.biosci.arizona.edu";
$remote_port = "6180";

$cgi = new CGI;

$contains = $cgi->param('contains');
$queryTaxa= $cgi->param('queryTaxa');

($queryTaxa)=($queryTaxa=~/^\s*(.*\w+)\s*$/); # delete initial or trailing space prior to SQL query

#$contains='all';
#$queryTaxa='Dalea pulchra';

my $cmd;

if ($contains eq 'all') {
   $cmd = 'relation|';
}
else {
   $cmd = 'any|';
}

$cmd = $cmd . $queryTaxa . "\n";

$socket = IO::Socket::INET->new(PeerAddr => $remote_host,
                                PeerPort => $remote_port,
                                Proto    => "tcp",
                                Type     => SOCK_STREAM)
    or die "Couldn't connect to $remote_host:$remote_port : $@\n";

# ... do something with the socket

print $socket $cmd;

$answer = <$socket>;

# send back search results

#print "$answer\n";

my @params = split(/&&&&/, $answer);

my $returnCode = $params[0];

my $sid  = GetDateTime() . int(rand(10000)); 
my $preURL = "http://loco.biosci.arizona.edu/cgi-bin/viewgenetree.cgi";

if($returnCode>0)
	{
	   my @trees = split(/,/,$params[1]);
	   my @queryInfo = split(/&&/,$params[2]);

	   foreach my $t (@trees) 
		{
		$treeLink= "<a href=\"$preURL?id=$sid&treename=$t&ncbi=$queryInfo[1]\"/><img src=\"$basePBicon/LittleTree.gif\" border=0 style=\"width: 15px; height: 20px;\"></a>\n";
		$treeH{$t}=$treeLink;
		}   
	doTable(\%treeH);
	}
elsif($returnCode==0)
	{
	print "Content-type: text/html\n\n";
	print "<html>";
	print "No gene tree was found for your query taxa.";
	print "</html>";
	}
else 
	{
	print "Content-type: text/html\n\n";
	print "<html>";
	print "<font color='red'>Error:</font> $params[1]\n";
	print "</html>";
	}



#print $answer;

# and terminate the connection when we're done
close($socket);




# return a string in YYYYMMDDHHMISS
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

sub doTable
{
my ($href)=shift;
my ($ti,$cl,$t);

use DBI;

do "pb_mysql.conf";
$basePB = "http://loco.biosci.arizona.edu/cgi-bin";
$basePBicon = "http://loco.biosci.arizona.edu/icons";

$tablename="nodes";
$tableClusterNodes="clusters_nodes";
$tableClusterSubtrees="clusters_subtrees";

$sortOrder="taxon_name";

my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",$user,$passwd);

$nr=0;
for $t (keys %{$href})
	{
	($ti,$cl)=($t=~/ti(\d+)_cl(\d+)/);
	$sql="select def,taxon_name,n_gi,n_ti, rank_flag from seqs,nodes,cluster_table where nodes.ti=cluster_table.ti_root and nodes.ti=$ti and ci=$cl and seqs.gi=cluster_table.seed_gi";
	$sh = $dbh->prepare($sql);
	$sh->execute;
	if ($rowHRef = $sh->fetchrow_hashref)  
		{
		++$rowCount;
		$table[$nr]={%{$rowHRef}}; # copy the hash and store a ref to it
		$table[$nr]{save_taxon_name}=$table[$nr]{taxon_name};
		$fmtTax=formatTaxonName($table[$nr]{taxon_name},$table[$nr]{rank_flag});
		$table[$nr]{taxon_name}="<a href=\"$basePBcgi/sql_getdesc.cgi?ti=$ti&db=$database\">$fmtTax</a>";
		if ($rowHRef->{n_gi}>$giCutoff)
			{ $table[$nr]{tree_link}="-"; }
		else	
			{ $table[$nr]{tree_link}=$href->{$t};}
		$table[$nr]{cluster}=$cl;
		++$nr;
		}
	$sh->finish;
	}

@sortedTable = sort {$a->{save_taxon_name} cmp $b->{save_taxon_name} } @table;
@table = @sortedTable;

print <<EOF;
Content-type: text/html\n\n
<html>
<html>\n
<table><tr>
<td><a href=\"$basePB/pb.cgi\"><img src=\"$basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Clusters containing query taxa</B></font></td>
</tr></table>
<hr>
EOF

# select seqs.gi, def from seqs,clusters_subtrees where clusters_subtrees.ti=247880 and clustid= 0 and seqs.gi=clusters_subtrees.gi limit 1;


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

@colTitles=("Group name","Cluster","Num GIs","Num TIs","Tree","Defline of longest sequence");
@colJustify=("left","center","center","center","center","left");
@cellWidth=(200,75,75,75,25,400);
@colOrder=('taxon_name','cluster','n_gi','n_ti','tree_link','def');

open FHO, ">-";
$FHRef=\*FHO;
printTable($nr,$align,$border,$width,$cellspacing,$colorRowHeader,\@table,$FHRef,\@colTitles,\@rowColor,\@colJustify, \@cellWidth,\@colOrder);
print "</td></tr>";

print "</table>";
printTailer($FHRef);
close FHO;
}

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
for $i (0..$numCols-1) {$tableWidth+=${$cellWidthRef}[$i];}

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

