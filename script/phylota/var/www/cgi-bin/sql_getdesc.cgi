# this is a legacy script file from phylota
#!/usr/bin/perl -w


# 	NEED TO FIX THE SINGLE QUOTES AROUND TAXON NAMES...


# TO DO: Also need to check cases in which taxon name is present both at epoch and now, but
# 	 no sequences were present at epoch (NCBI seems to put some nodes out before there is sequence)
#	 Currently, we just tag with yellow those taxa that had no taxon id at epoch...

# Retrieve the info from my version of the NCBI tax tree for a given TI and its children.
# Sorts the children info alphabetically by taxon name

use DBI;

use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});


my $headText = <<EOF;
This database provides a snapshot of the current taxonomic distribution of nucleotide sequences in GenBank (rel. 155.0).
Sequences are included from the non-EST, non-HTG divisions only.
The number of clusters (sets of homologous sequences) is estimated by all-against-all BLAST searches and sequence clustering (for all nodes with < 5000 sequences, and excluding sequences > 25,000 nt in length). For more information on how the
clustering was implemented click <a href="">here</a>. 
Model organisms are defined as any node (not subtree) having >100 clusters. The sequence numbers for model organisms do not propagate upward in the tree.
Cluster numbers link to a view of the data availability matrix for that node, which is useful for supermatrix and supertree construction.<br><br>
EOF

my $notesText = <<EOF;
<hr>
<font size="-1">
&nbsp&nbsp <sup>1</sup>Names refer to node and its subtree unless the term "node only" appears.<br>
&nbsp&nbsp <sup>2</sup>Taxa at species rank as determined by NCBI (including this node). Note that some of these have not been formally named yet and are not retrieved in certain NCBI Taxonomy searches (e.g., <i>Marina</i> sp. Lavin 5341), but they are associated with sequence(s) and are counted as species here.<br>
&nbsp&nbsp <sup>3</sup>Clusters built by exhaustive all-against-all BLAST searches. For further information of about this see <a href=\"$basePB/pb/pbhelp.htm\">here</a>. A dash (-) means there were too many sequences to cluster or no sequences at all.<br>
&nbsp&nbsp <sup>4</sup>Phylogenetically informative clusters have four or more taxa (not GIs) represented.<br>
</font>
EOF
# ..............................

$basetiNCBI=$pb::basetiNCBI;
$basePB    =$pb::basePB;
$basePBhtml=$pb::basePBhtml;
$basePBicon=$pb::basePBicon;


# set up default root node of this tree

$collection=0;

$qs=$ENV{'QUERY_STRING'};

#$qs="db=GB159&c=1&ti=20400&cl=0&mode=0"; # for debugging

@qargs=split ('&',$qs);
#do "pb_mysql.conf";
for $qarg (@qargs)
	{
	($opt,$val)=split ('=',$qarg);
	if ($opt eq "ti") 
		{$ti_anc_query = $val;}
	if ($opt eq "mode") 
		{$mode = $val;} # mode=0=show all states; 1=exclude model orgs
	if ($opt eq "db") 
		{$db = $val;} 
	if ($opt eq "c") 
		{$collection = $val;} # collection=1 means show counts from ti_specimen table
	}

if ($db)
	{$database=$db;}
else
	{$database=0;}

##
   $dbPrev=0; # deprecated
##
$tablename="nodes_$release";
$specimenTable="ti_specimen";

$gbRelease = $release;


	## Get the information on the higher taxon 

if ($collection)
	{	$sql = "select $tablename.*,count from $tablename left join $specimenTable on $tablename.ti=$specimenTable.ti where $tablename.ti=$ti_anc_query;"; }
else
	{	$sql = "select * from $tablename where ti=$ti_anc_query;"; }
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	%higher = %{$rowHRef};
	$higher{taxon_name} =~ s/'//g;
	$higher{common_name} =~ s/'//g;
	$ti_anc = $rowHRef->{ti_anc};
		# now we make new fields that weren't in the mysql data proper
	if ($mode==0)
		{
		$higher{n_gi}=$higher{n_gi_sub_model}+$higher{n_gi_sub_nonmodel};
		}
	if ($mode==1)
		{
		$higher{n_gi}=$higher{n_gi_sub_nonmodel};
		}

	$higher{n_clust}=$higher{n_clust_sub};
	$higher{n_PIclust}=$higher{n_PIclust_sub};
	if (!defined $higher{count}){$higher{count}="-";} # handle when there simply is no specimen for this ti in the spec table
	}
$sh->finish;

	# Do the following query to get the higher taxon's ancestor's name...(used in the output)

$sql = "select taxon_name from $tablename where ti=$higher{ti_anc};";
$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ $upToAnc = $rowHRef->{taxon_name}; $upToAnc =~ s/'//g; } # strip apostrophes
$sh->finish;


$nr=0;
$nc=6;

$data[$nr]=\%higher ;
$table[$nr]={formatRow($data[$nr],$nr,0)}; # stores a ref to a COPY of this returned hash, using the {} construct
$model[$nr]=0; # by convention we will never color the higher taxon name as model (color its NODE as model in next row)

#print "table:$table[$nr]->{taxon_name}\n";
++$nr;

if (!$higher{terminal_flag} && $higher{n_gi_node}>0) # this higher taxon has sequences all its own...
	{
	%higherNodeItself=%higher;
#	$higherNodeItself{taxon_name} .= " (node only) ";
	$higherNodeItself{n_gi}=$higherNodeItself{n_gi_node};
	$higherNodeItself{n_clust}=$higherNodeItself{n_clust_node};
	$higherNodeItself{n_PIclust}=$higherNodeItself{n_PIclust_node};
	$higherNodeItself{sampleClusterFlag}=0; # enforce this always?
	$higherNodeItself{count}="-"; # HACK for now; we'd like to display this, but don't yet keep it in table
	$data[$nr]=\%higherNodeItself ;
	$table[$nr]={formatRow($data[$nr],$nr,1)}; # stores a ref to a COPY of this returned hash, using the {} construct
	$model[$nr]=$higherNodeItself{model}; 
	++$nr;
	}


## Get the information on the children of the higher taxon

if ($collection)
	{	$sql = "select $tablename.*,count from $tablename left join $specimenTable on $tablename.ti=$specimenTable.ti where $tablename.ti_anc=$ti_anc_query order by taxon_name;"; }
else
	{	$sql = "select * from $tablename where ti_anc=$ti_anc_query order by taxon_name;"; }


$sh = $dbh->prepare($sql);
$sh->execute;
while ( $rowHRef = $sh->fetchrow_hashref)
	{
	%childH=%{$rowHRef};
	$childH{taxon_name} =~ s/'//g; # strip apostrophes
	$childH{common_name} =~ s/'//g;
	if ($childH{terminal_flag}) # store the appropriate values depending on whether node is terminal or not
				    # Convention will be that internal nodes always display subtree info
		{
		$childH{n_gi}=$childH{n_gi_node};
		$childH{n_clust}=$childH{n_clust_node};
		$childH{n_PIclust}=$childH{n_PIclust_node};
		}
	else
		{
		if ($mode==0) # display all sequence summaries, or just nonmodel...
			{
			$childH{n_gi}=$childH{n_gi_sub_model}+$childH{n_gi_sub_nonmodel};
			}
		if ($mode==1)
			{
			$childH{n_gi}=$childH{n_gi_sub_nonmodel};
			}
		$childH{n_clust}=$childH{n_clust_sub};
		$childH{n_PIclust}=$childH{n_PIclust_sub};
		}
	if (!defined $childH{count}){$childH{count}="-";} # handle when there simply is no specimen for this ti in the spec table
	$data[$nr]=\%childH; # do I need to make a new copy of this hash?
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
	$rowColor[$row]=$colorRowNormal;
	$rowColor[$row]=$colorRowModelTax if ($model[$row]);
	$rowColor[$row]=$colorRowNewTaxon if ($taxonNotFound[$row]);
	$rowColor[$row]=$colorRowHigherTax if ($row==0);
	}
# some global html stuff (maybe put somewhere better)

	$align="left";
	$border=1;
	$maxCellWidth=750;
	$cellspacing=0;
	$cellpadding=0;
	$altFlag=0;


# ...description of the table layout

if ($collection)
	{
	@colTitles=("NCBI taxon name<sup>1</sup>","&nbsp","Descendant species<sup>2</sup>","Descendant terminals","Sequences (GIs)","Seq. clusters<sup>3</sup>","Phylog. inform. seq. clusters<sup>4</sup>","ARIZ specimens");
	@colJustify=("left","center","right","right","right","right","right","right");
	@cellWidth=(250,25,100,100,100,100,100,100);
	@colOrder=('taxon_name','tax_link','n_sp_desc','n_leaf_desc','n_gi','n_clust','n_PIclust','count');
	}
else
	{
	@colTitles=("NCBI taxon name<sup>1</sup>","&nbsp","Descendant species<sup>2</sup>","Descendant terminals","Sequences (GIs)","Seq. clusters<sup>3</sup>","Phylog. inform. seq. clusters<sup>4</sup>");
	@colJustify=("left","center","right","right","right","right","right");
	@cellWidth=(250,25,100,100,100,100,100);
	@colOrder=('taxon_name','tax_link','n_sp_desc','n_leaf_desc','n_gi','n_clust','n_PIclust');
	}
$nc=@colOrder;

# Write the html 
# Next line required for CGI scripts

print "Content-type: text/html\n\n";

#print "<font size=\"+2\"><B>Sequence diversity and cluster set summaries (rel. $gbRelease)</B></font><hr><br>";

print <<EOF;
<html>\n
<table><tr>
<td><a href=\"$basePB/pb.cgi\"><img src=\"$basePBicon/PB_logo.gif\" style=\"width: 30px; height: 30px;\"></a></td>
<td> <font size=\"+2\" align=\"center\"><B>Sequence diversity and cluster set summaries (rel. $gbRelease)</B></font></td>
</tr></table>
<hr>
EOF

print "<font size=\"+1\">";
print "<table>";
print "<tr><td>";
#print $headText;

if ($mode==0)
	{
	print "Sequence tallies include those from \"model\" organisms. To <em>exclude</em> model organisms, click <a href=\"$cgiGet?c=$collection&ti=$ti_anc_query&mode=1&db=$database\">here</a>.";
	}
if ($mode==1)
	{
	print "Sequence tallies exclude those from \"model\" organisms. To <em>include</em> model organisms, click <a href=\"$cgiGet?c=$collection&ti=$ti_anc_query&mode=0&db=$database\">here</a>.";
	}
print "</td></tr>";

print "<tr><td>";
print "To show changes between this release and the previous one, click <a href=\"$cgiGetChanges?ti=$ti_anc_query&mode=0&db=$database&dbprev=$dbPrev\">here</a>.";
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
$fontOn="<font size=\"-1\" face=\"arial\">"; # Make sure these two lines stay global...
$fontOff="</font>";
$tid=$rowHRef->{ti} ;
$model=$rowHRef->{model}; # this array is used but not displayed directly in the table output
$comName="";
$comName=$rowHRef->{common_name};
if ($comName ne "") {$comName="($comName)";} # add parens
$rank=$rowHRef->{rank_flag};
$terminal=$rowHRef->{terminal_flag}; # used to decide on whether to link further
# format the taxon names as links to other levels in the hierarchy

$cgiGet="$basePB/sql_getdesc.cgi";
$cgiGetChanges="$basePB/sql_changes.cgi";
$cgiGetConcat="$basePB/sql_getconcat.cgi";
$cgiGetClusterSet="$basePB/sql_getclusterset.cgi";
$cgiGetSpecimens="$basePB/sql_getspecimens.cgi";

# taxon names...

$taxon_name=$rowHRef->{taxon_name};

if ($rank)
		{
		$taxon_name = "<I>" . $taxon_name . "</I>";
		if ($collection)
			{
			$numCol=$rowHRef->{count};
			$Tbl{count} = "<a href=\"$cgiGetSpecimens?ti=$tid&db=$database\">$numCol</a>";
			}
		}
if ($nodeFlag)
	{$taxon_name .= " (node only)";}
if (!$terminal && !$nodeFlag) # only if this taxon has descendants (specifically, desc. sequences!) do a link
		{
		if ($row==0)
			{
			$Tbl{taxon_name} = "$fontOn<B>$taxon_name</B> $comName $fontOff &nbsp&nbsp<a href=\"$cgiGet?c=$collection&ti=$ti_anc&mode=$mode&db=$database\"><font size=\"-2\">up to $upToAnc</font></a>";
			} # this link goes UP in the hierarchy
		else
			{
			$Tbl{taxon_name} = "$fontOn<a href=\"$cgiGet?c=$collection&ti=$tid&mode=$mode&db=$database\">$taxon_name</a>&nbsp $comName$fontOff";
			}
		}
else
	{$Tbl{taxon_name}=$taxon_name;}

# taxon links to NCBI

$Tbl{tax_link} = "<a href=\"$basetiNCBI". "$tid\"><img src=\"$basePBicon/ncbi.gif\" border=0 style=\"width: 10px; height: 15px;\"></a>" ;# build the link to NCBI tax

# links to the concatenation views of clusters
# First the loose clusters
if ($nodeFlag || $terminal)
	{
	$ntype=0; 
	$ncln=$Tbl{n_clust_node};
	$nclnPI=$Tbl{n_PIclust_node};
	}
else
	{
	$ntype=1; 
	$ncln=$Tbl{n_clust_sub};
	$nclnPI=$Tbl{n_PIclust_sub};
	}
if (!defined $ncln){$ncln=0};# these prevent the following numeric test from throwing an error and also mucking up html table display
if (!defined $nclnPI){$nclnPI=0};
if ($ncln>0)
	{ $Tbl{n_clust}="<a href=\"$cgiGetClusterSet?ti=$tid&ntype=$ntype&piflag=0&dflag=0&db=$database\">$ncln</font></a>";} # park this here!  
else
	{$Tbl{n_clust}="-";}
if ($nclnPI>0)
	{$Tbl{n_PIclust}="<a href=\"$cgiGetClusterSet?ti=$tid&ntype=$ntype&piflag=1&dflag=0&db=$database\">$nclnPI</font></a>";} # park this here!
else
	{
	if ($ncln > 0)
		{$Tbl{n_PIclust}=$nclnPI;}
	else
		{$Tbl{n_PIclust}="-";}
	}
# ...then the strict
return %Tbl;
}

