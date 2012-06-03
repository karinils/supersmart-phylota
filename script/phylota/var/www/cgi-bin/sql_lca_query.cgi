# this is a legacy script file from phylota
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
$basePBcgi =$basePB;
$basePBhtml=$pb::basePBhtml;
$basePBicon=$pb::basePBicon;



# set up default root node of this tree


# expecting an argument string like: ?ti=3423&ntype=1&piflag=0
# 	ntype=0 means get the node clusters, ntype=1 means get the subtrees clusters
$qs=$ENV{'QUERY_STRING'};

#$qs="qname=Astragalus%2CColutea&db=GB159";
#$qs="qname=Astragalus+lentiginosus%2C+Colutea+istria%2C+Astragalus&db=GB159";

@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "qname") 
		{
		@qname = split (/\%2C(?:\+)*/, $val); # split on special character plus any plus signs that cgi inserts..
		for $ix (0..$#qname)
			{
			$qname[$ix]=~s/\+/ /g; # case of spaces in the query, which are passed as '+'
			}
		}
	if ($opt eq "db") 
		{$database = $val;} 
	}
# mysql database info

$tablename="nodes_$release";

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD}); 

#$sql="select taxon_name,ti,ti_anc,terminal_flag,rank_flag from nodes where taxon_name=";
$sql="select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where ";

for $ix (0..$#qname)
	{
	#$sql .= "taxon_name = \"$qname[$ix]\" ";
	$sql .= "taxon_name = \"\'$qname[$ix]\'\" ";
	if ($ix < $#qname) {$sql .= " OR ";}
	}

		#print "sql=$sql\n";

print "Content-type: text/html\n\n";
print "<html>";
$sh = $dbh->prepare($sql);
$sh->execute;

print <<EOF;
<table><tr>
<td><a href=\"$basePBcgi/pb.cgi\"><img src=\"$basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Search results for LCA query</B></font></td>
</tr></table>
<hr>
EOF

print "Taxa in query:<ul>";
#print "$sql<br>";

$rowCount=0;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	++$rowCount;
	$tn =$rowHRef->{taxon_name};
	$tn=~s/'//g;
	$ti =$rowHRef->{ti};
	push @tis,$ti;
	$ti_anc =$rowHRef->{ti_anc};
	$tf =$rowHRef->{terminal_flag};
	$rf =$rowHRef->{rank_flag};
	if ($rf) 
		{$tn="<I>$tn</I>";} # add itals if needed
	print "<li>";
	if ($tf) # if query returns a terminal node, let's display the list of all its sibs
		{print "<a href=\"$basePB/sql_getdesc.cgi?ti=$ti_anc&mode=0&db=$database\">$tn</a><br>";}
	else
		{print "<a href=\"$basePB/sql_getdesc.cgi?ti=$ti&mode=0&db=$database\">$tn</a><br>";}
	print "</li>";
	}
print "</ul>";

$lca_q="'";
for $ix (0..$#tis)
	{
	$lca_q .=$tis[$ix];
	if ($ix<$#tis) {$lca_q .= ','} 
	}
$lca_q .= "'";
#print "lca_q = $lca_q <br><br>";

#$cmd = "/var/www/cgi-bin/ncbi-lca-request --host 128.196.198.9 -r " . $lca_q;
$cmd = "/var/www/cgi-bin/ncbi-lca-request -r " . $lca_q;
#print "$cmd<br>";
$lca =  `$cmd`;

($lcaNode) = ($lca =~/LCA is (\d+)/);

print "<hr>The least common ancestor node is:<br><br>";
#print "The lca is $lcaNode <br>";

$sql="select taxon_name,ti,ti_anc,terminal_flag,rank_flag from $tablename where ti=$lcaNode";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	++$rowCount;
	$tn =$rowHRef->{taxon_name};
	$tn=~s/'//g;
	$ti =$rowHRef->{ti};
	$ti_anc =$rowHRef->{ti_anc};
	$tf =$rowHRef->{terminal_flag};
	$rf =$rowHRef->{rank_flag};
	if ($rf) 
		{$tn="<I>$tn</I>";} # add itals if needed
	if ($tf) # if query returns a terminal node, let's display the list of all its sibs
		{print "<a href=\"$basePB/sql_getdesc.cgi?ti=$lcaNode&mode=0&db=$database\">$tn</a><br>";}
	else
		{print "<a href=\"$basePB/sql_getdesc.cgi?ti=$lcaNode&mode=0&db=$database\">$tn</a><br>";}
	}
#print "\n\n$rowCount matching taxon names(s) found\n";
print "</html>";
$sh->finish;



