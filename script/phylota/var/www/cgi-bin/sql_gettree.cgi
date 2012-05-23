#!/usr/bin/perl

# Script to format and display a tree from the database as a nexus file. 

use DBI;
use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;
$clusterTable = "clusters_$release";
$seqTable = "seqs";
$nodeTable= "nodes_$release";
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


$qs=$ENV{'QUERY_STRING'};

# To debug set both the following...
#$qs="ti=8460&ci=0&t=1&db=GB159&format=all";
#$qs="ti=163718&ci=7&db=GB159&t=0&format=ti";


$format="ti";
@qargs=split ('&',$qs);
do "pb_mysql.conf";
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$tiNode = $val;}
	if ($opt eq "ci") 
		{$ci = $val;}
#	if ($opt eq "db") 
#		{$database = $val;}
	if ($opt eq "format") 
		{$format = $val;}
			# Leaf label formats: gi, giti, names, ti, all
	if ($opt eq "t") 
		{$treeType = $val;}
	}

# mysql database info



if ($treeType==0) {$treeField="clustalw_tree"}
elsif ($treeType==1) {$treeField="muscle_tree"}
elsif ($treeType==2) {$treeField="strict_tree"};

$sql="select $treeField from $clusterTable where ci=$ci and ti_root=$tiNode and cl_type='subtree'";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$td=$rowHRef->{$treeField};
	}
$sh->finish;

print "Content-type: text/html\n\n";
print "<html>\n";
print "#nexus<br>begin trees;<br>";
$fmtTree = treeFormat($td);
if ($fmtTree eq "") 
		{print "[No tree in database for cluster $ci at node $tiNode]\n<br>"}
else
		{print "tree $treeField\_ti$tiNode\_ci$ci =  [&U] $fmtTree;\n<br>"}
print "end;<br>";
print "</html>\n";


sub treeFormat

{
my ($td)=@_;
my ($sql,$sh,$rowHRef);
if ($format =~/^gi$/i)
		{
		$td =~ s/(\d+)/gi$1/g;
		return $td;
		}

@gis = ($td=~/(\d+)/g); # pull out all the gis from the TD
for $gi (@gis) # this may be slower than one long sql query...
		{
		if ($format =~/^ti$|giti/i)
			{
			$sqls="select ti from $seqTable where gi=$gi";
			$shs = $dbh->prepare($sqls);
			$shs->execute;
			while ($rowHRefs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
				{
				$ti = $rowHRefs->{ti};
				$tiH{$gi}=$ti;
				}
			$shs->finish;
			}
		elsif ($format =~/names/i)
			{
			$sqls="select $nodeTable.ti,taxon_name from $nodeTable,$seqTable where $nodeTable.ti=$seqTable.ti and gi=$gi";
			$shs = $dbh->prepare($sqls);
			$shs->execute;
			while ($rowHRefs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
				{
				$ti = $rowHRefs->{ti};
				$name = $rowHRefs->{taxon_name};
				$name =~ s/\'//g; # hack to fix single quotes in cur db
				$name = $dbh->quote($name);
				$tiH{$gi}=$ti;
				$nameH{$gi}=$name;
				}
			$shs->finish;
			}
		elsif ($format =~/all/i)
			{
			$sqls="select $nodeTable.ti,taxon_name from $nodeTable,$seqTable where $nodeTable.ti=$seqTable.ti and gi=$gi";
			$shs = $dbh->prepare($sqls);
			$shs->execute;
			while ($rowHRefs = $shs->fetchrow_hashref)  # only returns one row (presumably) here and next...
				{
				$ti = $rowHRefs->{ti};
				$name = $rowHRefs->{taxon_name};
				$name =~ s/\'//g;	# remove any imbedded single quotes for later
				$tiH{$gi}=$ti;
				$nameH{$gi}=$name;
				}
			$shs->finish;
			}
		}
if ($format =~/^ti$/i)
		{
		$td =~ s/(\d+)/ti$tiH{$1}/g;
		}
elsif ($format =~/names/i)
		{
		$td =~ s/(\d+)/$nameH{$1}/g;
		}
elsif ($format =~/giti/i)
		{
		$td =~ s/(\d+)/gi$1\_ti$tiH{$1}/g;
		}
elsif ($format =~/all/i)
		{
		$td =~ s/(\d+)/'$nameH{$1}\_gi$1\_ti$tiH{$1}'/g;
		}
return "$td";
}
