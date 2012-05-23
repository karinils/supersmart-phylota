#!/usr/bin/perl

# cgi script to get the cluster as a fasta file
# note that the defline I write is NOT standard NCBI defline (ponder this for local BLUSTER use later!)

use DBI;

use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

$basetiNCBI=$pb::basetiNCBI;
$basePB    =$pb::basePB;
$basePBhtml=$pb::basePBhtml;
$basePBicon=$pb::basePBicon;

# set up default root node of this tree


# expecting an argument string like: ?ti=3423&ntype=1&piflag=0
# 	ntype=0 means get the node clusters, ntype=1 means get the subtrees clusters
$qs=$ENV{'QUERY_STRING'};

#$qs="ti=27046&cl=0&ntype=1";
$collection=0;
@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "qname") 
		{
		$qname = $val;
		if ($qname=~/\b\d+\b/)
			{
			$tiSearch=1;
			}
		else
			{
			# note the order of the following is important, because the get passes trailing spaces as 
			# +'s, which we then replace with spaces and have to delete those...
			$qname=~s/\+/ /g; # case of spaces in the query, which are passed as '+'
			$qname =~ s/^\s+//;
			$qname =~ s/\s+$//;
			$qname=~s/\*/%/g  # convert this wildcard symbol to the mysql symbol for its query;
			}
		}
	if ($opt eq "db") 
		{$db = $val;} 
	if ($opt eq "c") 
		{$collection = $val;} 
	}
# mysql database info

if ($db) {$database=$db;};
$tablename="nodes_$release";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

if ($tiSearch)
	{
	$sql="select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where ti=$qname";
	}
else
	{
# Following OR is a hack -- we need to fix the imbedded single quotes. Currently some tax names are not consistent about this
	$sql="select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where (taxon_name LIKE \"\'$qname\'\" or taxon_name LIKE \"$qname\") order by taxon_name";
	}
print "Content-type: text/html\n\n";
print "<html>";
print <<EOF;
<table><tr>
<td><a href=\"$basePB/pb.cgi\"><img src=\"$basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Search results for name/ID query:</B></font></td>
</tr></table>
<hr>
EOF
$sh = $dbh->prepare($sql);
$sh->execute;

$qname=~s/%/\*/g; 
print "Query on \"$qname\":\n";
print "<ul>";

$rowCount=0;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	++$rowCount;
	$tn =$rowHRef->{taxon_name};
	$ti =$rowHRef->{ti};
	$ti_anc =$rowHRef->{ti_anc};
	$tf =$rowHRef->{terminal_flag};
	$rf =$rowHRef->{rank_flag};
	if ($rf) 
		{$tn="<I>$tn</I>";} # add itals if needed
	print "<li>";
	if ($tf) # if query returns a terminal node, let's display the list of all its sibs
		{print "<a href=\"$basePB/sql_getdesc.cgi?c=$collection&ti=$ti_anc&mode=0&db=$database\">$tn</a><br>";}
	else
		{print "<a href=\"$basePB/sql_getdesc.cgi?c=$collection&ti=$ti&mode=0&db=$database\">$tn</a><br>";}
	print "</li>";
	}
print "</ul>";
if ($rowCount==1) {$word="was";}
else {$word="were";}
print "<br><B>There $word $rowCount matching taxon name/id(s)</B>";
if ($rowCount==0)
	{
	print "<br><br>Hint: if you were searching for a specific species, try searching for the genus name instead to retrieve related species.<br>";
	}
print "</html>";
$sh->finish;



