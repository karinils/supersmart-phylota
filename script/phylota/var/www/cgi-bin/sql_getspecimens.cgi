#!/usr/bin/perl -w

use DBI;

my $notesText = <<EOF;
<hr>
<font size="-1">
&nbsp&nbsp <sup>1</sup>Names refer to node and its subtree unless the term "node only" appears.<br>
&nbsp&nbsp <sup>2</sup>Taxa at species level rank as annotated by NCBI.<br>
&nbsp&nbsp <sup>3</sup>Clusters built by exhaustive all-against-all BLAST searches. For further information of about this see <a href=\"http://loco.biosci.arizona.edu/pb/pbhelp.htm\">here</a>. A dash (-) means there were too many sequences to cluster or no sequences at all.<br>
&nbsp&nbsp <sup>4</sup>Phylogenetically informative clusters have four or more taxa (not GIs) represented.<br>
</font>
EOF
# ..............................

$basetiNCBI="http://www.ncbi.nih.gov/Taxonomy/Browser/wwwtax.cgi?lvl=0&id="; # for returning taxonomy web page
$basePB    ="http://loco.biosci.arizona.edu/cgi-bin";
$basePBhtml="http://loco.biosci.arizona.edu/html";
$basePBicon="http://loco.biosci.arizona.edu/icons";


# set up default root node of this tree

$qs=$ENV{'QUERY_STRING'};

#$qs="db=GB159&ti=47080"; # for debugging

@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$ti = $val;}
	if ($opt eq "db") 
		{$database = $val;} 
	}

# mysql database info

$host="localhost";
$user="sanderm";
$passwd="phylota"; # password for the database
$tablename="nodes";


my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",$user,$passwd) or die $DBI::errstr;

	## Get the information on the higher taxon 

$sql = "select rank_flag,taxon_name from $tablename where ti=$ti;";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$taxon_name = $rowHRef->{taxon_name};
	$rank = $rowHRef->{rank_flag};
	}
$sh->finish;



## GO get the ARIZ data and return values in hash H

$nr=0;

# mysql database info

$host="ag2.calsnet.arizona.edu";
$user="herb_read";
$passwd="vles22"; # password for the database
$database_sp="ua_herbarium";
$table1="tbl_specimens";
$table2="tbl_taxa";

$dbh = DBI->connect("DBI:mysql:database=$database_sp;host=$host",$user,$passwd);

$sh = $dbh->prepare("select accession_number, scientific_name, first_collector, collnumprefix, collnumber, collnumsuffix, date_collected, country, state_province from $table1 inner join $table2 on $table1.taxa_id = $table2.taxa_id where deleted=0 and deaccessioned=0 and scientific_name like \"$taxon_name%\""); 

$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
        {
        $accession = $rowHRef->{'accession_number'};
        if (! defined $accession) {$rowHRef->{'accession_number'}="-";}
        $sci_name = $rowHRef->{'scientific_name'};
	if (! defined $sci_name) {$rowHRef->{'scientific_name'}="-";}
        $collector = $rowHRef->{'first_collector'};
	if (! defined $collector) {$rowHRef->{'first_collector'}="-";}

        $coll1 = $rowHRef->{'collnumprefix'};
        $coll2 = $rowHRef->{'collnumber'};
        $coll3 = $rowHRef->{'collnumsuffix'};
	if (defined $coll1) {
		$coll = "$coll1";
		if (defined $coll2) {
			$coll .= "-$coll2";
			if (defined $coll3) {$coll .= "-$coll3";}
			}
		} 
	elsif (defined $coll2) {
		$coll = "$coll2";
		if (defined $coll3) {
                        $coll .= "-$coll3";
			}
		}
	elsif (defined $coll3) {
 		$coll = $coll3;
		}
	if (defined $coll) {$rowHRef->{'coll'} = $coll;}
	else {$rowHRef->{'coll'} = "-";}

        $date = $rowHRef->{'date_collected'};
	if (! defined $date) {$rowHRef->{'date_collected'}="-";}
        $country = $rowHRef->{'country'};
	if (! defined $country) {$rowHRef->{'country'}="-";}
        $state = $rowHRef->{'state_province'};
	if (! defined $state) {$rowHRef->{'state_province'}="-";}

	$rowHRef->{'scientific_name'} = "<I>" . $sci_name . "</I>"; 
	%H=%{$rowHRef};
	$table[$nr]={%{$rowHRef}}; # do I need to make a new copy of this hash?
	++$nr;
        }
$sh->finish;
$dbh->disconnect;



# Assign row colors
$colorRowNormal="beige";
$colorRowHeader="lightblue";
for $row (0..$#table)
	{
	$rowColor[$row]=$colorRowNormal;
	}
# some global html stuff (maybe put somewhere better)

	$align="left";
	$border=1;
	$maxCellWidth=750;
	$cellspacing=0;
	$cellpadding=0;
	$altFlag=0;


# ...description of the table layout

@colTitles=("Accession Number","Scientific Name","Collector","Collection Number","Collection Date","Country","State");
@colJustify=("left","left","left","left","center","center","center");
@cellWidth=(100,200,100,100,100,100,100);
@colOrder=('accession_number','scientific_name','first_collector','coll','date_collected','country','state_province');
$nc=@colOrder;



# Write the html 
# Next line required for CGI scripts

print "Content-type: text/html\n\n";


print <<EOF;
<html>\n
<table><tr>
<td><a href=\"$basePB/pb.cgi\"><img src=\"$basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>ARIZ Specimen Report</B></font></td>
</tr></table>
<hr>
EOF

print "<font size=\"+1\">";
print "<table>";


print "<tr><td>";
print "</font>";
$title = "Phylota TaxBrowser Mirror Table";
open FHO, ">-";
$FHRef=\*FHO;
printHeader($title,$FHRef);
printTable($nr,$nc,$align,$border,$width,$cellspacing,$colorRowHeader,\@table,$FHRef,\@colTitles,\@rowColor,\@colJustify, \@cellWidth,\@colOrder);
print "</td></tr>";

print "<tr><td>";
#print $notesText;
print "</td></tr>";

print "</table>";
printTailer($FHRef);
close FHO;

# ****************************************************************************
sub printTable

# Takes a reference to a matrix of strings for the elements of the table.

# So far it seems to set default column widths the way I want them without further ado...

{
my ($nr,$nc,$align,$border,$width,$cellspacing,$headerbgcolor,$tableRef,$FH,$colTitlesRef,$rowColorRef,$colJustify,$cellWidthRef,$colOrderRef)=@_;
my ($i,$j,$tableWidth);
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
		print $FH "\t<td width=\"${$cellWidthRef}[$j]\" align=\"${$colJustify}[$j]\">${$tableRef}[$i]{$colKey}</td>\n";
		}
	print $FH "</tr>\n";
	}
print $FH "</table>\n";
print $FH "</body>\n";
}
# ****************************************************************************

sub printTailer
{
my ($FH)=@_;
print $FH "</html>\n";
}


sub printHeader
{
my ($title,$FH)=@_;
print $FH "<html>\n";
print $FH "<head>\n";
print $FH "<title>$title</title>\n";
print $FH "</head>\n";
}

