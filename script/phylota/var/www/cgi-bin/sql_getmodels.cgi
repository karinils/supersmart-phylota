#!/usr/bin/perl

# cgi script to report stats on model organisms 

use DBI;
use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD
});

$nodeTable="nodes_$release";

$seqCutoff=10000;
$clustCutoff=100;


$qs=$ENV{'QUERY_STRING'};
#$qs="db=GB159";
@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "db") 
		{$database = $val;}
	}
# mysql database info

$sql="select ti_anc,taxon_name,rank_flag,n_gi_node,n_clust_node from $nodeTable where n_gi_node>$seqCutoff or n_clust_node>=$clustCutoff";
$sh = $dbh->prepare($sql);
$sh->execute;
$rowCount=0;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	++$rowCount;
	$tiName=$rowHRef->{taxon_name};
	$ancH{$tiName}=$rowHRef->{ti_anc};
	$giH{$tiName}=$rowHRef->{n_gi_node};
	if (0==($clH{$tiName}=$rowHRef->{n_clust_node}))
		{$clH{$tiName}='-'};
	$rankH{$tiName}=$rowHRef->{rank_flag};
	}
$sh->finish;


printHeader();

print "<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">\n";
print "<tr bgcolor=\"lightblue\"><th>Taxon</th><th>Sequences</th><th>Clusters</th></tr>\n";

for $tn (sort {$giH{$b}<=>$giH{$a}}keys %giH )  # keys of any of these hashes will do
	{
	formatRow ($tn,$ancH{$tn},$rankH{$tn},$giH{$tn},$clH{$tn});
	}


print "</table>";

print "<br><a href=\"$pb::basePB/pb.cgi\">Back to Phylota Browser home</a>";

print "</html>\n";

sub formatRow
{
my ($tiName,$tiAnc,$tiNodeRank,$n_gi,$n_clust_node)=@_;
my ($fon,$foff);
$fon="<font size=\"-1\" face=\"arial\">";$foff="</font>";
print "<tr bgcolor=\"beige\">";
if ($tiNodeRank)
	{$tiName="<I>$tiName</I>";}

$nameRef="<a href=\"$pb::basePB/sql_getdesc.cgi?ti=$tiAnc&mode=0&db=$database\">$tiName</a>";

print "<td align=\"left\">$fon$nameRef$foff</td>";
print "<td align=\"center\">$fon$n_gi$foff</td>";
print "<td align=\"center\">$fon$n_clust_node$foff</td>";
print "</tr>\n";
}
sub printHeader
{
my ($title)=@_;
print "Content-type: text/html\n\n";
print "<html>\n";
print "<font size=\"+2\"><B>'Model organisms' in release $database</B></font><hr>";
print "<head>\n";
print "<title>$title</title>\n";
print "</head>\n";
}

