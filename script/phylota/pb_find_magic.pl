#!/usr/bin/perl

# Makes a list of magic nodes in a tree based on the 'nodes' table. These are nodes with n_gi_sub_nonmodel<=cutoff and
# parent node > cutoff.

# Illustrates the use of a self join to look at parent child data in the same nodes table
# Uses aliases for the table names to spoof mysql into thinking there are two tables


use DBI;

$cutoff=30000; # gi size cutoff for node selection

$host="localhost";
$user="sanderm";
$passwd="phylota"; # password for the database
$database="GB159";


my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",$user,$passwd);

$sql=<<EOF;
select child.taxon_name,parent.ti as ti_p, child.n_gi_sub_nonmodel as ngi, child.ti as ti_c, parent.n_leaf_desc,child.n_clust_sub as n_clust, child.n_leaf_desc as n_leaf_desc_c
from nodes as parent, nodes as child
where child.ti_anc=parent.ti and child.n_gi_sub_nonmodel<=$cutoff and parent.n_gi_sub_nonmodel>$cutoff ;
EOF

$sh = $dbh->prepare($sql);
$sh->execute;
while ($rowHRef = $sh->fetchrow_hashref)  # only returns one row (presumably) here and next...
	{
	$name_c =$rowHRef->{taxon_name};
	$ti_p =$rowHRef->{ti_p};
	$ti_c =$rowHRef->{ti_c};
	$n_leaf_desc_c=$rowHRef->{n_leaf_desc_c};
	$n_clust=$rowHRef->{n_clust};
	$n_gi=$rowHRef->{ngi};
	$H{$ti_c}=$n_leaf_desc_c;
	print "$ti_c\t$n_leaf_desc_c\t$n_gi\t$n_clust\t$name_c\n";
		
	$ngiH{$ti_c}=$n_gi;
	$nclustH{$ti_c}=$n_clust;
	}
$sh->finish;
for $p (keys %H)
	{
	$nlv=$H{$p};
	$totlv += $nlv;
	$ngi=$ngiH{$p};
#	print "$p\t$H{$p}\t$ngiH{$p}\n";
	$n_clust=$nclustH{$p};
	if ($ngi>0 && $n_clust==0)
		{
#		print "No clusters but some gis: $p\t$nsp\t$ngi\t$n_clust\n";
		}
	if ($n_clust==0)
		{
		++$tooFew;
#		print "No clusters: $p\t$nsp\t$ngi\t$n_clust\n";
		}
	if ($ngi>20000)
		{
		++$tooBig;
#		print "Too Big: $p\t$nsp\t$ngi\n";
		};
	if ($ngi==0){++$zeroGI};
	if ($nlv==0){++$zeroTaxa};
	if ($nlv==1){++$singleton};
	++$count;
	}
print "Number of magic nodes: $count\n";
print "Number of magic nodes with ngi>20000:$tooBig\n";
print "Number of magic nodes with ngi=0:$zeroGI\n";
print "Number of magic nodes with nlv=0:$zeroTaxa\n";
print "Number of magic nodes with nlv=1:$singleton\n";
print "Number of magic nodes with n_clust=0:$tooFew\n";
print "Number of species descended from magic nodes:$totlv\n";
