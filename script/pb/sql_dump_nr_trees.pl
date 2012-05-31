#!/usr/bin/perl

# Writes a text file with all nonredundant trees in the database at the level of the magic nodes
# This means any PI cluster at a magic node, even if it is identical to its child (because we do
# not report the child). Note that there are subtrees or subdata sets at shallower nodes, so it
# is a special use of nonredundant. Maybe maximal is better!

use DBI;
use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
die if (!($configFile));
$format="all";

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();

# ************************************************************

$clusterTable="clusters" ."\_$release";
$nodeTable   ="nodes"    ."\_$release";
$seqTable    ="seqs";
$treeField = "muscle_tree"; # field in table having tree

$fn = "pb.dmp.nr.trees.$release";
die "Refusing to overwrite existing file $fn\n" if (-e $fn);
open FH, ">$fn" or die;


# ************************************************************

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


$sql="select ti_root,ci,$treeField from $clusterTable where PI=1 and ci_anc IS NULL and $treeField IS NOT NULL "; 

$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$td =$rowHRef->{$treeField};
	$ti =$rowHRef->{ti_root};
	$ci =$rowHRef->{ci};
	$fmtTree = treeFormat($td);
	print FH "ti$ti\_ci$ci\t$fmtTree\n";  
#die if (++$count>10);
	}
$sh->finish;
close FH;




sub treeFormat

{
my ($td)=@_;


my ($sql,$sh,$rowHRef);
if ($format =~/^gi$/i)
		{
#		$td =~ s/(\d+)/gi$1/g;
		return $td;
		}

@gis = ($td=~/gi(\d+)/g); # pull out all the gis from the TD
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
				$name =~ s/ /\_/g;	# turn space to underscore
				$tiH{$gi}=$ti;
				$nameH{$gi}=$name;
				}
			$shs->finish;
			}
		}
if ($format =~/^ti$/i)
		{
		$td =~ s/gi(\d+)/ti$tiH{$1}/g;
		}
elsif ($format =~/names/i)
		{
		$td =~ s/gi(\d+)/$nameH{$1}/g;
		}
elsif ($format =~/giti/i)
		{
		$td =~ s/gi(\d+)/gi$1\_ti$tiH{$1}/g;
		}
elsif ($format =~/all/i)
		{
		$td =~ s/gi(\d+)/$nameH{$1}\_gi$1\_ti$tiH{$1}/g;
		}
return "$td";
}

