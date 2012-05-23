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
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



$basetiNCBI="http://www.ncbi.nih.gov/Taxonomy/Browser/wwwtax.cgi?lvl=0&id="; # for returning taxonomy web page

# set up default root node of this tree


# expecting an argument string like: ?ti=3423&ntype=1&piflag=0
# 	ntype=0 means get the node clusters, ntype=1 means get the subtrees clusters
$qs=$ENV{'QUERY_STRING'};

#$qs="ti=27046&cl=0&ntype=1";

@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$tiNode = $val;}
	if ($opt eq "ntype") 
		{$ntype = $val;}
	if ($opt eq "cl") 
		{$cluster = $val;}
	if ($opt eq "strict") 
		{$strict = $val;}
	if ($opt eq "db") 
		{$database = $val;}
	}
# mysql database info

if (!$database) {$database="GB157";}
$tablename="nodes_$release";
$clusterTable = "ci_gi_$release";

if ($ntype==0) 
	{$nquery="\'node\'";}
else
	{$nquery="\'subtree\'";}


$sql="select seqs.gi,seqs.seq,seqs.def from seqs,$clusterTable where $clusterTable.ti=$tiNode and $clusterTable.clustid=$cluster and seqs.gi=$clusterTable.gi and cl_type=$nquery";

print "Content-type: text/html\n\n";
print "<html><pre>";
$sh = $dbh->prepare($sql);
$sh->execute;
$fastaLen=80;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$gi =$rowHRef->{gi};
	$def=$rowHRef->{def};
	$seq=$rowHRef->{seq};
	print ">gi|$gi|$def\n";
	$len=length($seq);
	for ($i=0;$i<$len;$i+=$fastaLen)
		{
		print substr ($seq,$i,$fastaLen);
		print "\n";
		}
	}
print "</pre></html>";
$sh->finish;


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
