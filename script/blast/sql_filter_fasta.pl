#!/usr/bin/perl


# Takes an input fasta file where the def line starts with any of >gi|xx, >gixx, or >xx,
# and filters it to extract one sequence per genus such that the species with the most
# unambiguous sites is kept out of the genus.

use lib '/home/sanderm/blast'; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;


$minunambig=0;

while ($fl = shift @ARGV)
  {
  if ($fl eq '-c') {$configFile = shift @ARGV;}
  if ($fl eq '-f') {$inFile = shift @ARGV;}
  }
# Initialize a bunch of locations, etc.

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;
$clusterTable = "clusters_$release";
$seqTable = "seqs";
$nodeTable= "nodes_$release";
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

open FH, "<$inFile";

$first = 1;
while (<FH>)
	{
	chomp;
	if (/>/)
		{
		if ($first) 
			{$first = 0}
		else
			{
			# first handle the previous record...
			$seqH{$gi}=$seq;
			$unambigH{$gi}=numUnambig($seq);
			$tiH{$gi}=$ti;
			$tisH{$ti}=1;
			$nameH{$gi}=$name;
			($genus)=split ' ', $name; # first word is genus (usually!)
			$genusH{$genus}++;
			$newDefH{$gi}= ">$name\_$prefix$gi$\_ti$ti\_$defSuffix";
#			print ">$name\_$prefix$gi$\_ti$ti\_$defSuffix\n";
			if (! (exists $bestGenusNumUnambigH{$genus})) 
				{$bestGenusNumUnambigH{$genus}=$unambigH{$gi}; $bestGIinGenusH{$genus}=$gi}
			else
				{
				if ($unambigH{$gi} > $bestGenusNumUnambigH{$genus})
					{
					#print "Dumping $newDefH{$bestGIinGenusH{$genus}} ($unambigH{$bestGIinGenusH{$genus}} unambig sites) ... keeping $newDefH{$gi} ($unambigH{$gi}) \n";
					$bestGenusNumUnambigH{$genus}=$unambigH{$gi}; 
					$bestGIinGenusH{$genus}=$gi;
					}
				}
			#print "$name $genus $gi unambig=$unambigH{$gi} best gi:$bestGIinGenusH{$genus} best gi num:$bestGenusNumUnambigH{$genus}\n";

			}
		$seq="";
		($prefix,$gi,$ti,$name,$defSuffix)=parseDef($_);
		}
	else
		{
		$seq .= $_;
		}
	}
## handle last record...
			$seqH{$gi}=$seq;
			$unambigH{$gi}=numUnambig($seq);
			$tiH{$gi}=$ti;
			$tisH{$ti}=1;
			$nameH{$gi}=$name;
			($genus)=split ' ', $name; # first word is genus (usually!)
			$genusH{$genus}++;
			$newDefH{$gi}= ">$name\_$prefix$gi$\_ti$ti\_$defSuffix";
#			print ">$name\_$prefix$gi$\_ti$ti\_$defSuffix\n";
			if (! (exists $bestGenusNumUnambigH{$genus})) 
				{$bestGenusNumUnambigH{$genus}=$unambigH{$gi}; $bestGIinGenusH{$genus}=$gi}
			else
				{
				if ($unambigH{$gi} > $bestGenusNumUnambigH{$genus})
					{
					#print "Dumping $newDefH{$bestGIinGenusH{$genus}} ($unambigH{$bestGIinGenusH{$genus}} unambig sites) ... keeping $newDefH{$gi} ($unambigH{$gi}) \n";
					$bestGenusNumUnambigH{$genus}=$unambigH{$gi}; 
					$bestGIinGenusH{$genus}=$gi;
					}
				}
			#print "$name $genus $gi unambig=$unambigH{$gi} best gi:$bestGIinGenusH{$genus} best gi num:$bestGenusNumUnambigH{$genus}\n";
## ... done with that
close FH;
$numTI = keys %tisH;
$numGen= keys %genusH;
$numSeq= keys %seqH;

print "$numSeq sequences: Unique TIs=$numTI; Unique genera = $numGen\n";

#for $gi (keys %seqH)
#	{
#	print "$newDefH{$gi}\n";
#	print "$seqH{$gi}\n";
#	}


$fastaLen=80;
for $genus (sort keys %bestGIinGenusH)
	{
	$gi = $bestGIinGenusH{$genus};
	$def= $newDefH{$gi};
	print "$def\n";
	$seq = $seqH{$gi};
	$len=length($seq);
	for ($i=0;$i<$len;$i+=$fastaLen)
		{
		print substr ($seq,$i,$fastaLen);
		print "\n";
		}
	}

# Return the number of unambiguous sites in a seq
sub numUnambig
{
my ($s) = @_;
my $count=0;
$count++ while $s =~ /[acgtACGT]/g;
return $count;
}

sub parseDef
{
my ($def)=@_;

my ($prefix,$gi,$defSuffix)=($def =~ /^[>]*(gi|gi\||)(\d+)(.*)/);  #either gi|XX ... giXX .. or XX
($ti,$name) = lookup ($gi);
return ($prefix,$gi,$ti,$name,$defSuffix);
}


sub lookup

{
	my ($gi)=@_;

	$sqls="select $nodeTable.ti,taxon_name from $nodeTable,$seqTable where $nodeTable.ti=$seqTable.ti and gi=$gi";
	$shs = $dbh->prepare($sqls);
	$shs->execute;
	my ($ti,$name) = $shs->fetchrow_array;
	$name =~ s/\'//g; # hack to fix single quotes in cur db
	$name = $dbh->quote($name);
	$shs->finish;
	return ($ti,$name);
}


