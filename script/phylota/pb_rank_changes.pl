# this is a legacy script file from phylota
#!/usr/bin/perl -w

use DBI;
use pb;

$numRows=50;
$curCutoff=100; # current taxon size must be at least this

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
die if (!($configFile));

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$prevRelease = 168;

# ************************************************************
# Table names with proper release numbers
$nodeTable="nodes" ."\_$release";
$nodeTablePrev="nodes" ."\_$prevRelease";
# ************************************************************
# mysql initializations 

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


my $sql="select ti,taxon_name,n_otu_desc from $nodeTable where terminal_flag=0 and rank=\"\'family\'\" and n_sp_desc>$curCutoff"; 
my $sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
	$curH{$H->{ti}}=$H->{n_otu_desc};
	$nameH{$H->{ti}}=$H->{taxon_name};
	}
$sh->finish;

$sql="select ti,n_otu_desc from $nodeTablePrev where terminal_flag=0 and rank=\"\'family\'\""; 
$sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
	$prevH{$H->{ti}}=$H->{n_otu_desc};
	}
$sh->finish;

for $curTI (keys %curH)
	{
	$curN = $curH{$curTI};
	if (exists $prevH{$curTI})
		{
		$prevN = $prevH{$curTI};
		if ($prevN > 0)
			{
			$f = ($curN-$prevN)/$prevN;
			if ($f>0)
				{
				#print "$curTI\t$nameH{$curTI}\t$prevN\t$curN\t$f\n";
				$rH{$curTI}=100*$f; # percent increase
				}
			}
		}
	}
@sorted = sort {$rH{$b} <=> $rH{$a}} keys %rH;
$count=1;
for $ti (@sorted)
	{
	if ($curH{$ti} > $curCutoff)
		{
		$name = $nameH{$ti}; $name =~ s/'//g;
		$percent=sprintf("%4.1f",$rH{$ti});
		print "$count\t$ti\t$name\t$curH{$ti}\t$prevH{$ti}\t$percent\n" if ($count <= $numRows) ;
		++$count;
		}
	}

