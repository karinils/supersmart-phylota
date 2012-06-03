# this is a legacy script file from phylota
#!/usr/bin/perl -w

use DBI;

# mysql database info

#do "pb_mysql.conf";
$tablename="summary_stats";

# $server="ceiba.biosci.arizona.edu";
# $basePB="http://$server/cgi-bin";
# $basePBhtml="http://$server/pb";
# $basePBicon="http://$server/icons";

use pb;
# DBOSS added full path to pb.conf.browser
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

#my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",$user,$passwd);

$sh = $dbh->prepare("select * from $tablename"); 
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{ 
	$gb_rel =$rowHRef->{'gb_release'};
	$gb_rel_date = $rowHRef->{'gb_rel_date'};
	$numGIs =$rowHRef->{'n_gis'};
	$numNodes = $rowHRef->{'n_nodes'};
	$numTerms = $rowHRef->{'n_nodes_term'};
	$nodesWithClusts = $rowHRef->{'n_clusts_node'};
	$nodesWithClustsSub= $rowHRef->{'n_clusts_sub'};
	$nodesWithSequence = $rowHRef->{'n_nodes_with_sequence'};
	$n_clusts=$rowHRef->{'n_clusts'};
	$n_PI_clusts=$rowHRef->{'n_PI_clusts'};
	$n_singleton_clusts=$rowHRef->{'n_singleton_clusts'};
	$n_large_gi_clusts=$rowHRef->{'n_large_gi_clusts'};
	$n_large_ti_clusts=$rowHRef->{'n_large_ti_clusts'};
	$n_largest_gi_clust=$rowHRef->{'n_largest_gi_clust'};
	$n_largest_ti_clust=$rowHRef->{'n_largest_ti_clust'};
	}
$sh->finish;


# Write the HTML

print "Content-type: text/html\n\n";
print "<html>\n";

print <<EOF;
<center><img src="$pb::basePBicon/PB_logo_large.gif" style="width: 110px; height: 90px;"></center> <br><br>
<font size="+3"><center><B><a href="http://$pb::server/phylota/index.htm">PhyLoTA</a> Browser (rel. 1.5)</B></font></center><br><br>
This database provides a snapshot of the current taxonomic distribution of nucleotide sequences in GenBank.
Its purpose is to convey information about the potential phylogenetic data sets (<em>clusters</em>, or sets of homologous sequences) that can be constructed from the database for taxa of interest. It mirrors the NCBI
taxonomy tree.
The number of clusters is estimated by all-against-all BLAST searches and sequence clustering algorithms (for all nodes with < 35,000 sequences, and excluding sequences > 25,000 nt in length). 
Model organisms are defined as any node (not subtree) having >100 clusters or more than 10,000 sequences. By default, sequence tallies for model organisms propogate upward in the tree along with nonmodel organisms, but this information can be excluded, so that users can get a sense of taxonomic breadth of the
sequence diversity in the database. Note, however, that the bulk of "genomic" data for model organisms is not entered in the database at all (see below for types of sequences included).
Cluster tallies are linked to a view of the <b>data availability matrix</b> for that node in the taxonomy tree, which can provide useful guidance for supermatrix and supertree construction. Sequences for each cluster can be downloaded as an unaligned FASTA file for further analysis. Provisional alignments and phylogenetic trees are under construction.<br><br>
To see a list of "biodiversity research hotspots" (families with the largest increase in species since the last release) click 
<a href="$pb::basePB/sql_getrankings.cgi">here</a> (New!). 

For a list of model organisms click 
<a href="$pb::basePB/sql_getmodels.cgi?db=$database">here</a>.

For more information on how the clustering was implemented click 
<a href="$pb::basePBhtml/pbhelp.htm">here</a>.  
<br><br> 
For more information on the database structure, including <b>downloads</b> of this or previous releases of the entire database click
<a href="$pb::$basePBhtml/pb/Download.htm">here</a> (New!).

Finally, for more information about the developers, how to cite, etc., click <a href="$pb::$basePBhtml/pb/authors.htm">here</a>
<br><br> 


<hr>
<table>
<tr><td>
<form action="$pb::basePB/sql_taxquery.cgi" method="get" name="form1" id="form1">
<b>Query with a taxon name or id number:</b>
<input type="text" size="35" maxlength="75" name="qname">
<input type="submit" value="Submit" >
<input type=\"hidden\" name=\"db\" value=\"$database\">
</form>
</td>
<td> &nbsp&nbsp<a href="$pb::basePB/advsearch.cgi?db=$database"><font size=-1>All search options</a></td>
<!-- This code is currently broken <td> &nbsp&nbsp<a href="$pb::basePBhtml/seqinput.html"><font size=-1>BLAST search</a>(New!) </td> --> 
</tr>
<tr><td><font > &nbsp&nbsp&nbsp<i>Examples</i>: Amorpha <i>or</i> Amor* <i>or</i> Amorpha * <i>or</i> 48130</font></td><tr>
</table>
<hr>
Quick links to specific nodes:<br>
<ul>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=2759&mode=0&db=$database">Eukaryotes (root)</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=3398&mode=0&db=$database">Angiosperms</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=3803&mode=0&db=$database">Fabaceae</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=33208&mode=0&db=$database">Metazoa</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=7742&mode=0&db=$database">Vertebrates</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=8459&mode=0&db=$database">Turtles</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=9681&mode=0&db=$database">Felids</a>
<li><a href="$pb::basePB/sql_getdesc.cgi?ti=4751&mode=0&db=$database">Fungi</a>


</ul>

<hr><B>Types of sequences included:</B> Only "core" nucleotide data are included, which excludes ESTs, STSs, and other kinds of bulk or high-throughput sequences.<br>
<B>Taxonomic coverage:</B> At present the database contains sequences from eukaryotes. These represent the PLN, MAM, PRI, ROD, VRT, and INV divisions of GenBank. <br><br>
EOF


print "GenBank release:$gb_rel ($gb_rel_date)<br>";
print "Number of sequences in this database:$numGIs<br>";
print "Number of nodes in our subtree(s) of the NCBI taxonomy tree:$numNodes<br>";
print "Number of terminal nodes:$numTerms<br>";
print "Number of nodes clustered (usually terminal taxa):$nodesWithClusts<br>";
print "Number of subtrees clustered (always internal nodes):$nodesWithClustsSub<br>";
print "Number of nodes with sequences that can be clustered:$nodesWithSequence<br>";
print "<br>Clusters:<br>";
print "<ul>";
print "<li>Total number of clusters:$n_clusts</li>";
print "<li>Number of phylogenetically informative clusters (TIs >= 4):$n_PI_clusts</li>";
print "<li>Number of singleton clusters (GIs = 1):$n_singleton_clusts</li>";
print "<li>Number of large clusters (GIs >= 100):$n_large_gi_clusts</li>";
print "<li>Number of large clusters (TIs >= 100):$n_large_ti_clusts</li>";
print "<li>Size of largest cluster (w.r.t. GIs):$n_largest_gi_clust</li>";
print "<li>Size of largest cluster (w.r.t. TIs):$n_largest_ti_clust</li>";
print "</ul>";

print "<hr><I>Questions or comments? Contact Mike Sanderson (sanderm at email dot arizona dot edu)</I>";
print "</html>";

