# this is a legacy script file from phylota
#!/usr/bin/perl

# cgi script to report stats ranking biggest increases in species diversity since last release


use DBI;
use pb;

$numRows=50;
$curCutoff=100; # current taxon size must be at least this

# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
die if (!($configFile));

%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$prevRelease = pb::previousGBRelease();

$qs=$ENV{'QUERY_STRING'};
#$qs="db=GB159";
@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "db") 
		{$database = $val;}
	}

# ************************************************************
# Table names with proper release numbers
$nodeTable="nodes" ."\_$release";
$nodeTablePrev="nodes" ."\_$prevRelease";
# ************************************************************
# mysql initializations 

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

printHeader();

print "<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">\n";
print "<tr bgcolor=\"lightblue\"><th>Rank</th><th>Taxon</th><th><i>N</i> (rel. $release)</th><th><i>N</i> (rel. $prevRelease)</th><th>Percent increase</th></tr>\n";





my $sql="select ti,taxon_name,n_sp_desc from $nodeTable where terminal_flag=0 and rank=\"\'family\'\" and n_sp_desc>$curCutoff"; 
my $sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
	$curH{$H->{ti}}=$H->{n_sp_desc};
	$nameH{$H->{ti}}=$H->{taxon_name};
	}
$sh->finish;

$sql="select ti,n_sp_desc from $nodeTablePrev where terminal_flag=0 and rank=\"\'family\'\""; 
$sh = $dbh->prepare($sql);
$sh->execute;
while ($H = $sh->fetchrow_hashref)  
	{
	$prevH{$H->{ti}}=$H->{n_sp_desc};
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
		if ($count <= $numRows)
			{formatRow ($count,$ti,$name,$curH{$ti},$prevH{$ti},$percent);}
		++$count;
		}
	}

print "</table>";
print "<br><a href=\"$pb::basePB/pb.cgi\">Back to Phylota Browser home</a>";
print "</html>\n";

#################################################





sub formatRow
{
my ($rank,$ti,$tiName,$nCur,$nPrev,$percent)=@_;
my ($fon,$foff);
$fon="<font size=\"-1\" face=\"arial\">";$foff="</font>";
print "<tr bgcolor=\"beige\">";

$nameRef="<a href=\"$pb::basePB/sql_getdesc.cgi?ti=$ti&mode=0&db=$database\">$tiName</a>";

print "<td align=\"left\">$fon$rank$foff</td>";
print "<td align=\"left\">$fon$nameRef$foff</td>";
print "<td align=\"center\">$fon$nCur$foff</td>";
print "<td align=\"center\">$fon$nPrev$foff</td>";
print "<td align=\"center\">$fon$percent$foff</td>";
print "</tr>\n";
}
sub printHeader
{
my ($title)=@_;
print "Content-type: text/html\n\n";
print "<html>\n";
print "<font size=\"+2\"><B>'Biodiversity research hotspots'</B></font><br> (Increases in species diversity between current and previous releases for taxa at 'family' rank currently exceeding 100 species; top 50 only)<hr>";
print "<head>\n";
print "<title>$title</title>\n";
print "</head>\n";
}

