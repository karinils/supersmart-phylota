#!/usr/bin/perl -w

# Shows the differences between two GB releases from the mysql database.
# See sql_getdesc for details of formatting etc. 

# Need to depracate the cgi parameters for db and dbprev; no longer needed, get them from config

use DBI;

use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$gbRelease=pb::currentGBRelease();
$gbReleasePrev=pb::previousGBRelease();
$database=$release;
$database=0;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

my $notesText = <<EOF;
<hr>
<font size="-1">
&nbsp&nbsp <sup>1</sup>Names refer to node and its subtree unless the term "node only" appears.<br>
&nbsp&nbsp <sup>2</sup>Taxa at species level rank as annotated by NCBI.<br>
&nbsp&nbsp <sup>3</sup>Note that the changes in the number of clusters summed across child taxa do not necessarily sum to the changes in parent taxon (clustering is done separately at each node)<br>
&nbsp&nbsp <sup>4</sup>Phylogenetically informative clusters have four or more taxa (not GIs) represented.<br>
</font>
EOF
# ..............................

$basetiNCBI="http://www.ncbi.nih.gov/Taxonomy/Browser/wwwtax.cgi?lvl=0&id="; # for returning taxonomy web page
$cgiGet="$pb::basePB/sql_getdesc.cgi";
$cgiGetChanges="$pb::basePB/sql_changes.cgi";



# set up default root node of this tree


$qs=$ENV{'QUERY_STRING'};

#$qs="ti=20400&cl=0&mode=0"; # for debugging

@qargs=split ('&',$qs);
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$ti_anc_query = $val;}
	if ($opt eq "mode") 
		{$mode = $val;} # mode=0=show all states; 1=exclude model orgs
	if ($opt eq "db")  # these two options deprectated since we get them from a file in cgi-bin directory
		{$db = $val;} 
	if ($opt eq "dbprev") 
		{$dbPrev = $val;} 
	}

# mysql database info


#if ($db)
#	{$database=$db;}
#else
#	{die;}
$db=0; $dbprev=0;
$tablename="nodes_$gbRelease";
$tablenamePrev="nodes_$gbReleasePrev";

	## Get the information on the higher taxon 

$sql = "select * from $tablename where ti=$ti_anc_query;";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	%higher = %{$rowHRef};
	$ti_anc = $rowHRef->{ti_anc};
		# now we make new fields that weren't in the mysql data proper
	if ($mode==0)
		{
		$higher{n_gi}=$higher{n_gi_sub_model}+$higher{n_gi_sub_model_long}+$higher{n_gi_sub_nonmodel}+$higher{n_gi_sub_nonmodel_long};
		}
	if ($mode==1)
		{
		$higher{n_gi}=$higher{n_gi_sub_nonmodel}+$higher{n_gi_sub_nonmodel_long};
		}

	$higher{n_clust}=$higher{n_clust_sub};
	$higher{n_PIclust}=$higher{n_PIclust_sub};
	%higherNodeItself=%higher; # this will be used below, saved because I'm about to overwrite %higher
	}
$sh->finish;

	# Do the following query to get the higher taxon's ancestor's name...(used in the output)

$sql = "select taxon_name from $tablename where ti=$higher{ti_anc};";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $upToAnc = $rowHRef->{taxon_name};$upToAnc =~ s/'//g;}
$sh->finish;

# now get the "previous" database's higher taxon
$sql = "select * from $tablenamePrev where ti=$ti_anc_query;";
$sh = $dbh->prepare($sql);
$sh->execute;
if ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	%higherPrev = %{$rowHRef};
	if ($mode==0)
		{
		$higherPrev{n_gi}=$higherPrev{n_gi_sub_model}+$higherPrev{n_gi_sub_model_long}+$higherPrev{n_gi_sub_nonmodel}+$higherPrev{n_gi_sub_nonmodel_long};
		}
	if ($mode==1)
		{
		$higherPrev{n_gi}=$higherPrev{n_gi_sub_nonmodel}+$higherPrev{n_gi_sub_nonmodel_long};
		}

	$higherPrev{n_clust}=$higherPrev{n_clust_sub};
	$higherPrev{n_PIclust}=$higherPrev{n_PIclust_sub};

	$higher{n_gi}-=$higherPrev{n_gi};
	$higher{n_sp_desc}-=$higherPrev{n_sp_desc};
	$higher{n_clust}-=$higherPrev{n_clust};
	$higher{n_PIclust}-=$higherPrev{n_PIclust};
	$taxonNotFound[0]=0;
	}
else
	{ 
# This must be a higher taxon that was not found in the previous database, so it's a new taxon.
# In the table, we'll just report the stats for the newer database, since these would have been calculated just
# by subtracting zeros from everything.

	$taxonNotFound[0]=1;
	}
$sh->finish;

$nr=0;
$nc=6;

$data[$nr]=\%higher ;
$table[$nr]={formatRow($data[$nr],$nr,0)}; # stores a ref to a COPY of this returned hash, using the {} construct
$model[$nr]=0; # by convention we will never color the higher taxon name as model (color its NODE as model in next row)

++$nr;

# this higher taxon has sequences all its own...
if (!$higherNodeItself{terminal_flag} && $higherNodeItself{n_gi_node}>0) 
	{
	$higherNodeItself{n_gi}=$higherNodeItself{n_gi_node}+$higherNodeItself{n_gi_node_long}-($higherPrev{n_gi_node}+$higherPrev{n_gi_node_long});
	$higherNodeItself{n_clust}=$higherNodeItself{n_clust_node}-$higherPrev{n_clust_node};
	$higherNodeItself{n_PIclust}=$higherNodeItself{n_PIclust_node}-$higherPrev{n_PIclust_node};
	$higherNodeItself{n_sp_desc}-=$higherPrev{n_sp_desc};
	$data[$nr]=\%higherNodeItself ;
	$table[$nr]={formatRow($data[$nr],$nr,1)}; # stores a ref to a COPY of this returned hash, using the {} construct
	$model[$nr]=$higherNodeItself{model}; 
	++$nr;
	}

# still "using" previous release; go ahead and get child info and hash it for next step
# Careful with the next query, the ancestor node in the PREVIOUS database might not even exist

$sql = "select * from $tablenamePrev where ti_anc=$ti_anc_query ;";
$sh = $dbh->prepare($sql);
$sh->execute;
while ( $rowHRef = $sh->fetchrow_hashref)
	{
	%childH=%{$rowHRef};
	if ($childH{terminal_flag}) # store the appropriate values depending on whether node is terminal or not
				    # Convention will be that internal nodes always display subtree info
		{
		$childH{n_gi}=$childH{n_gi_node}+$childH{n_gi_node_long};
		$childH{n_clust}=$childH{n_clust_node};
		$childH{n_PIclust}=$childH{n_PIclust_node};
		}
	else
		{
		if ($mode==0) # display all sequence summaries, or just nonmodel...
			{
			$childH{n_gi}=$childH{n_gi_sub_model}+$childH{n_gi_sub_model_long}+$childH{n_gi_sub_nonmodel}+$childH{n_gi_sub_nonmodel_long};
			}
		if ($mode==1)
			{
			$childH{n_gi}=$childH{n_gi_sub_nonmodel}+$childH{n_gi_sub_nonmodel_long};
			}
		$childH{n_clust}=$childH{n_clust_sub};
		$childH{n_PIclust}=$childH{n_PIclust_sub};
		}
	#$prevH{$childH{ti}}=\%childH; # hash where key is child's ti and val is the whole hash record for that ti 
	$prevH{$childH{ti}}={%childH}; # hash where key is child's ti and val is the whole hash record for that ti 
	} 

$sh->finish;

## Get the information on the children of the higher taxon for current release

$sql = "select * from $tablename where ti_anc=$ti_anc_query order by taxon_name;";
$sh = $dbh->prepare($sql);
$sh->execute;
while ( $rowHRef = $sh->fetchrow_hashref)
	{
	%childH=%{$rowHRef};
	$tiChild=$childH{ti};
	if ($childH{terminal_flag}) # store the appropriate values depending on whether node is terminal or not
				    # Convention will be that internal nodes always display subtree info
		{
		$childH{n_gi}=$childH{n_gi_node}+$childH{n_gi_node_long};
		$childH{n_clust}=$childH{n_clust_node};
		$childH{n_PIclust}=$childH{n_PIclust_node};
		}
	else
		{
		if ($mode==0) # display all sequence summaries, or just nonmodel...
			{
			$childH{n_gi}=$childH{n_gi_sub_model}+$childH{n_gi_sub_model_long}+$childH{n_gi_sub_nonmodel}+$childH{n_gi_sub_nonmodel_long};
			}
		if ($mode==1)
			{
			$childH{n_gi}=$childH{n_gi_sub_nonmodel}+$childH{n_gi_sub_nonmodel_long};
			}
		$childH{n_clust}=$childH{n_clust_sub};
		$childH{n_PIclust}=$childH{n_PIclust_sub};
		}
# DEAL WITH CASE WHERE PREV RECORD IS SIMPLY MISSING...(new taxon in new release of DB)
# ...big complication, if in the previous DB, a node was missing but is children are present, my code doesn't
# set the prevH hash for the children (because the mysql query fails), and thus I can't properly do the following test
	if (exists $prevH{$tiChild})
		{
	$childH{n_gi}-=$prevH{$tiChild}{n_gi};
	$childH{n_sp_desc}-=$prevH{$tiChild}{n_sp_desc};
	$childH{n_clust}-=$prevH{$tiChild}{n_clust};
	$childH{n_PIclust}-=$prevH{$tiChild}{n_PIclust};
	$taxonNotFound[$nr]=0;
		}
	else
		{
		# check database !!!!!!!!!!! and redo the next...
		$sql = "select * from $tablenamePrev where ti=$tiChild ;";
		$sh1 = $dbh->prepare($sql);
		$sh1->execute;
		if ( $rowHRef = $sh1->fetchrow_hashref)
			{
			$taxonNotFound[$nr]=0;
			}
		else
			{
			$taxonNotFound[$nr]=1;
			}
		$sh1->finish;
		}
	#$data[$nr]=\%childH; # do I need to make a new copy of this hash?
	$data[$nr]={%childH}; # do I need to make a new copy of this hash?
	$table[$nr]={formatRow($data[$nr],$nr,0)};
	$model[$nr]=$childH{model}; 
	++$nr;
	} 

$sh->finish;
$dbh->disconnect;

# Assign row colors
$colorRowNewTaxon="yellow";
$colorRowModelTax="lightgrey";
$colorRowHigherTax="beige";
$colorRowNormal="beige";
$colorRowHeader="lightblue";
for $row (0..$#table)
	{
	$rowColor[$row]=$colorRowHigherTax if ($row==0);
	$rowColor[$row]=$colorRowNormal;
	$rowColor[$row]=$colorRowModelTax if ($model[$row]);
	$rowColor[$row]=$colorRowNewTaxon if ($taxonNotFound[$row]); #this will override the higher taxon color set above...
	}
# some global html stuff (maybe put somewhere better)

	$align="left";
	$border=1;
	$maxCellWidth=750;
	$cellspacing=0;
	$cellpadding=0;
	$altFlag=0;


# ...description of the table layout

@colTitles=("NCBI taxon name<sup>1</sup>","&nbsp","Descendant species<sup>2</sup>","Sequences (GIs)","Seq. clusters<sup>3</sup>","Phylog. inform. seq. clusters<sup>3,4</sup>");
@colJustify=("left","center","right","right","right","right");
@cellWidth=(250,25,100,100,100,100);
@colOrder=('taxon_name','tax_link','n_sp_desc','n_gi','n_clust','n_PIclust');

# Write the html 
# Next line required for CGI scripts

print "Content-type: text/html\n\n";

print "<table><tr> <td><a href=\"$pb::basePB/pb.cgi\"><img src=\"$pb::basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a> </td>"; 

print "<td><font size=\"+2\"><B>Changes from GenBank release $gbReleasePrev to $gbRelease</font></td>";

print "</tr></table> <hr>";



#print "<font size=\"+2\"><B>Changes from GenBank release <a href=\"$cgiGet?ti=$ti_anc_query&mode=1&db=$dbPrev\">$gbReleasePrev</a> to <a href=\"$cgiGet?ti=$ti_anc_query&mode=1&db=$db\">$gbRelease</a></B></font><br><br>";
print "<font size=\"+1\">";

print "<table>";
print "<tr><td>";

if ($mode==0)
	{
	print "Sequence tallies include those from \"model\" organisms. To <em>exclude</em> model organisms, click <a href=\"$cgiGetChanges?ti=$ti_anc_query&mode=1&db=$database&dbprev=$dbPrev\">here</a>.";
	}
if ($mode==1)
	{
	print "Sequence tallies exclude those from \"model\" organisms. To <em>include</em> model organisms, click <a href=\"$cgiGetChanges?ti=$ti_anc_query&mode=0&db=$database&dbprev=$dbPrev\">here</a>.";
	}
print "</td></tr>";
print "<tr><td>";
print "Taxa new since the last release are highlighted in yellow.";
print "</td></tr>";
print "<tr><td>";
print "</font>";
$title = "Phylota TaxBrowser Mirror Table";
open FHO, ">-";
$FHRef=\*FHO;
printHeader($title,$FHRef);
printTable($nr,$nc,$align,$border,$width,$cellspacing,$colorRowHeader,\@table,$FHRef,\@colTitles,\@rowColor,\@colJustify, \@cellWidth,\@colOrder);
print "</td></tr>";

print "<tr><td>";
print $notesText;
print "</td></tr>";

print "<tr><td>";
print "<br><br><a href=\"$pb::basePB/pb.cgi\">Back to Phylota Browser home</a>";
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
my ($i,$j,$fontOn,$fontOff,$tableWidth);
$tableWidth=0; # must = total of all columns...
$numCols=@{$cellWidthRef};
for $i (0..$numCols) {$tableWidth+=${$cellWidthRef}[$i];}
print $FH "<body>\n";
print $FH "<table width=\"$tableWidth\" align=\"$align\" border=\"$border\" cellspacing=\"$cellspacing\" cellpadding=\"$cellpadding\" >\n";
print $FH "<tr bgcolor=\"$headerbgcolor\">\n";
for $j (0..$nc-1)
		{
		print $FH "\t<th width=\"${$cellWidthRef}[$j]\">$fontOn${$colTitlesRef}[$j] $fontOff</th>\n"; # table headers for columns
		}	
print $FH "</tr>\n";
for $i (0..$nr-1)
	{
	print $FH "<tr bgcolor=\"${$rowColorRef}[$i]\">\n";
	for $j (0..$nc-1)
		{ 
		$colKey=$colOrderRef->[$j];
		if ($i==0)
			{
			print $FH "\t<td width=\"${$cellWidthRef}[$j]\" align=\"${$colJustify}[$j]\">${$tableRef}[$i]{$colKey}</td>\n";
			}
		else
			{
			if ($colKey eq "taxon_name") # awful hack to force a reliable indent for species names
				{
				print $FH "\t<td width=\"${$cellWidthRef}[0]\">\n";
				print $FH "\t\t<table><tr><td>&nbsp&nbsp&nbsp&nbsp</td>";
				#print $FH "<td>$tableRef[$i]->{$colKey} </td>";
				print $FH "<td>${$tableRef}[$i]{$colKey} </td>";
				print $FH "</tr></table>\n";
				print $FH "\t</td>\n";
				}
			else
				{print $FH "\t<td width=\"${$cellWidthRef}[$j]\" align=\"${$colJustify}[$j]\">${$tableRef}[$i]{$colKey}</td>\n";}
			}
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

sub min
{
if ($_[0] > $_[1]) {return $_[1];}
return $_[0];
}


sub formatRow
{
my ($rowHRef,$row,$nodeFlag)=@_;  # if nodeFlag==1, then treat this as a "(node)" row
my ($taxon_name,$tid,$model,$comName,$rank,$terminal,$cgiGet,$taxLink,%Tbl);
%Tbl=%{$rowHRef}; # make an initial new copy of this hash and then modify if below for some fields
$fontOn="<font size=\"-1\" face=\"arial\">";
$fontOff="</font>";
$tid=$rowHRef->{ti} ;
$model=$rowHRef->{model}; # this array is used but not displayed directly in the table output
$comName="";
$comName=$rowHRef->{common_name};
$comName =~ s/'//g; # strip apostrophes

if ($comName ne "") {$comName="($comName)";} # add parens
$rank=$rowHRef->{rank_flag};
$terminal=$rowHRef->{terminal_flag}; # used to decide on whether to link further
# format the taxon names as links to other levels in the hierarchy

# taxon names...

$taxon_name=$rowHRef->{taxon_name};
$taxon_name =~ s/'//g; # strip apostrophes

if ($rank)
		{$taxon_name = "<I>" . $taxon_name . "</I>";}
if ($nodeFlag)
	{$taxon_name .= " (node only)";}
if (!$terminal && !$nodeFlag) # only if this taxon has descendants (specifically, desc. sequences!) do a link
		{
		if ($row==0)
			{
			$Tbl{taxon_name} = "$fontOn<B>$taxon_name</B> $comName $fontOff &nbsp&nbsp<a href=\"$cgiGetChanges?ti=$ti_anc&mode=$mode&db=$database&dbprev=$dbPrev\"><font size=\"-2\">up to $upToAnc</font></a>";
			} # this link goes UP in the hierarchy
		else
			{
			$Tbl{taxon_name} = "$fontOn<a href=\"$cgiGetChanges?ti=$tid&mode=$mode&db=$database&dbprev=$dbPrev\">$taxon_name</a>&nbsp $comName$fontOff";
			}
		}
else
	{$Tbl{taxon_name}=$taxon_name;}

# taxon links to NCBI

$Tbl{tax_link} = "<a href=\"$pb::basetiNCBI". "$tid\"><img src=\"$pb::basePBicon/ncbi.gif\" style=\"width: 10px; height: 15px;\"></a>" ;# build the link to NCBI tax

$Tbl{n_gi}=sprintf("%+8i",$Tbl{n_gi});
$Tbl{n_sp_desc}=sprintf("%+8i",$Tbl{n_sp_desc});
$Tbl{n_clust}=sprintf("%+8i",$Tbl{n_clust});
$Tbl{n_PIclust}=sprintf("%+8i",$Tbl{n_PIclust});
return %Tbl;
}

