# this is a legacy script file from phylota
#!/usr/bin/perl

# Author: E. Gilbert April 08
# Version 2

# Modified very slightly by MJS

use IO::Socket;

#use strict;
use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Bio::Seq;
use Bio::Tools::Run::RemoteBlast;
use DBI;


use pb;
# DBOSS
$configFile = "/var/www/cgi-bin/pb.conf.browser";
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$database=$release;

my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});

$seqTable="seqs";
$nodeTable="nodes_$release";
$clusterTable="clusters_$release";
$cigiTable="ci_gi_$release";




my $remote_host = "ceiba.biosci.arizona.edu";
my $remote_port = "6180";

my $cgi = new CGI;

#Follwing section is the remote BLAST code
#Get query parameters
my $querySeq   = $cgi->param('SEQ') || '';
my $expect     = $cgi->param('EXPECT') || '1e-20';
my $maxNumSeq  = $cgi->param('MAX_NUM_SEQ') || '10';
my $wordSize   = $cgi->param('WORD_SIZE') || '28';
my $matchScore = $cgi->param('MATCH_SCORES') || '1,-2';
my $gapCost    = $cgi->param('GAPCOSTS') || '5  2';

open FHO, ">-";
my $FHRef = \*FHO;
printHeader("PHYLOTA: BLAST results");
doTable();
printFooter();
close FHO;

sub doTable {
	#my ( $sql, @table );

	my $sid    = GetDateTime() . int( rand(10000) );

$querySeq = " cacaaacagaaactaaagcaagtgttggattcaaagctggtgttaaagattataaattgacttattatactcctgactat
gaaaccaaagatagtgatatcttggcagcattccgagtaactcctcaacctggcgttccgcctgaagaagcaggtgccgc
ggtagctgctgaatcttctactggtacatggacaactgtgtggaccgatgggcttaccagtcttgatcgttacaaaggac
gatgctaccacatcgagcccgttgctggagaagaaaatcaatatattgcttatgtagcttatcccttagacctttttgaa
gaaggttctgttactaacatgtttacttcgattgtaggtaatgtatttgggttcaaggccctgcgtgctctacgtctgga
agatttgcgaatccccccttcttattttaaaactttccaaggcccgcctcacggcatccaagttgagagagataaattga
acaagtacggccgtcctctattgggatgtactattaaaccaaaattggggttatccgcgaagaattacggtagagcggtt
tatgaatgtctgcgtggtggacttgattttaccaaagatgatgagaatgtgaattcccaaccatttatgcgttggagaga
ccgtttcttattttgtgtcgaagctatttataaagcacaggccgaaacaggtgaagtcaaagggcattacttgaatgcta
ctgcaggtacatgcgaagaaatgatcaaaagagctgtatttgcccgagaattgggcgctcctatcgtaatgcatgactac
ttaacaggtggattcactgcaaatactagcttggctcattattgccgagataatggtctacttcttcatatccaccgtgc
aatgcatgcagttatcgatagacagaagaatcatggtatgcactttcgtgtactagctaaagccttacgtttgtctggtg
gagatcatgttcacgctggtaccgtagtaggtaaacttgaaggggaaagagaaatcactttaggttttgttgatttacta
cgtgatgattatattgagaaagatcgaagccgcggtatttatttcactcaggattgggtctctctaccgggcgttctgcc
tgttgcttcggggggtattcacgtttggcatatgcctgctcttaccgagatctttggagacgattccgtactacaattcg
gggggggaactttaggacacccttggggaaatgcacctggtgccgtagctaaccgagtagctgtagaagcatgtgtaaag
gctcgtaatgagggacgtgatcttgctcgtgaggggaatgaaattattcgtcaggctagcaaatggagtcctgaattagc
tgctgcttgtgaagtatggaaagaaattaaatttgaattccctgcaatggatactttgtaa";

	my %giHash = blastSeq($querySeq, $expect, $maxNumSeq, $wordSize, $matchScore, $gapCost);
	if(%giHash){

		my $nr = 0;
# CURRENTLY ONLY LOOKS IN SUBTREE CLUSTERS...
############  FIX   $sql = "SELECT distinct def,strict_tree,clusters_subtrees.gi,clustid,nodes.ti,ci,n_ti,n_gi,taxon_name,rank_flag from seqs,nodes,cluster_table, clusters_subtrees where seqs.gi=clusters_subtrees.gi and nodes.ti=cluster_table.ti_root and clustid=ci and clusters_subtrees.ti=ti_root and cl_type='subtree' and (clusters_subtrees.gi in (".join(",",keys %giHash)."))";
$sql = "SELECT distinct def,strict_tree,$cigiTable.gi,clustid,$nodeTable.ti,ci,n_ti,n_gi,taxon_name,rank_flag from $seqTable,$nodeTable,$clusterTable, $cigiTable where $seqTable.gi=$cigiTable.gi and $nodeTable.ti=$clusterTable.ti_root and clustid=ci and $cigiTable.ti=ti_root and cl_type='subtree' and ($cigiTable.gi in (".join(",",keys %giHash)."))";
		my $sh = $dbh->prepare($sql);
		$sh->execute;
		my $rowCount = 0;
		while ( my $rowHRef = $sh->fetchrow_hashref ) 
			{
			++$rowCount;

			$ti=$rowHRef->{ti};
			$gi=$rowHRef->{gi};
			$ci=$rowHRef->{ci};
			$def=$rowHRef->{def};
			$strict=$rowHRef->{strict_tree};
			$taxon_name=$rowHRef->{taxon_name};
			$rank_flag=$rowHRef->{rank_flag};
			$tici = $ti . "_" . $ci;
			$countHitsH{$tici}++;
			$samplegiH{$tici}=$gi;
			$taxon_nameH{$tici}=$taxon_name;
			$rank_flagH{$tici}=$rank_flag;
			$defH{$tici}=$def;
			$strictH{$tici}=$strict;
			$n_giH{$tici}=$rowHRef->{n_gi};
			$n_tiH{$tici}=$rowHRef->{n_ti};
			}
		for $tici (keys %taxon_nameH)
			{

			($ti,$ci)=split /\_/, $tici;
			#Set taxon link
			$table[$nr]{def}=$defH{$tici};
			$table[$nr]{n_gi}=$n_giH{$tici};
			$table[$nr]{n_ti}=$n_tiH{$tici};
			$table[$nr]{num_hits}=$countHitsH{$tici};
			$table[$nr]{save_taxon_name} = $taxon_nameH{$tici};
			my $fmtTax = formatTaxonName( $table[$nr]{save_taxon_name}, $rank_flagH{$tici} );
			$table[$nr]{taxon_name} = "<a href=\"/cgi-bin/sql_getdesc.cgi?ti=$ti&db=$database\">$fmtTax</a>";

			#Set cluster link
			$table[$nr]{ci} = "<a href=\"/cgi-bin/sql_getcluster.cgi?ti=$ti&cl=$ci&ntype=1&db=$database\">$ci</a>";

			#Set GI link
			$gi = $samplegiH{$tici};
			$table[$nr]{gi} = "<a href='http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=nuccore&id=".$gi."' target='_blank'>$gi</a>";

			#Set tree link
			my $tree = $strictH{$tici};
			my $treeLink = "-"; 
			if($tree)
				{
				$treeLink = "<a href='/cgi-bin/viewgenetree.cgi?id=".$sid."&treename=ti".$ti."_cl".$ci."'>";
				$treeLink .= "<img src='/icons/LittleTree.gif' border=0 style='width: 15px; height: 20px;'>";
				$treeLink .= "</a>";
				}
			$table[$nr]{tree_link} = $treeLink;
			
			#Set score and evalue from giHash
			$table[$nr]{score} = $giHash{$gi}{score};
			$table[$nr]{evalue} = $giHash{$gi}{evalue};
			
			++$nr;
			}
		$sh->finish;
	
		my @sortedTable = sort { $a->{n_gi} <=> $b->{n_gi} } @table;
		@table = @sortedTable;
	
		printTable($nr, \@table);
		#print "<div style='border-top:10px;'>SQL: ".$sql."</div>";
	}
	else{
		print "BLAST of sequence returned no results.";
	}
}

# ****************************************************************************
sub printTable{
	
	my ($nr, $tableRef) = @_;

	print <<WEB_TABLE;
		<table border='1' cellspacing='0' cellpadding='2' class='pbtable'>
			<tr>
				<th width="100">Representative hit GI</th>
				<th width="375">Defline of representative hit</th>
				<th width="50">Hits within cluster<sup>1</sup></th>
				<th width="200">Taxon name of cluster</th>
				<th width="50">Cluster</th>
				<th width="50">GIs in cluster</th>
				<th width="50">TaxIDs in cluster</th>
				<th width="25">Tree<sup>2</sup></th>
			</tr>
WEB_TABLE

	my @colOrder = ( 'gi', 'def', 'num_hits','taxon_name', 'ci', 'n_gi', 'n_ti', 'tree_link' );
	my @colJustify = ( "left", "left", "center","left", "center", "right", "right", "center" );

	my ( $i, $j );
	my $numCols    = @colOrder;

	#$fon  = "<font size=\"-1\" face=\"arial\">";
	for $i ( 0 .. $nr - 1 ) {
		print $FHRef "<tr>\n";
		for $j ( 0 .. $numCols - 1 ) {
			my $colKey = $colOrder[$j];
			print $FHRef "\t<td align=\"$colJustify[$j]\">${$tableRef}[$i]{$colKey}</td>\n";
		}
		print $FHRef "</tr>\n";
	}

	print $FHRef "</table>\n";
	print <<EOF;
<hr>
&nbsp&nbsp<sup>1</sup>
Number of distinct sequences found within this cluster that hit to the query sequence. These may
be within more than one taxon.
&nbsp&nbsp<sup>2</sup><br>
Trees are <em>unrooted</em> strict consensus trees of the two majority rule consensus trees constructed by fast bootstrap parsimony algorithm in PAUP* 4.0 using default ClustalW and Muscle alignments. Only trees for (taxon) phylogenetically informative clusters with fewer than 1000 sequences are generated. 
EOF
}

sub formatTaxonName{

  # puts in italics except for Roman subspecific ranks
	my ($tn,$rank)=@_;
	my ($ret);

	if ($rank) {
		$tn =~ s/var\./\<\/I\>var\.\<I\>/;
		$tn =~ s/subsp\./\<\/I\>subsp\.\<I\>/;
		$ret = "<I>" . $tn . "</I>";
	}
	else { 
		$ret = $tn;
	}
	return $ret;
}

sub printHeader {
	my ( $title ) = @_;
	my $basePB     = "http://loco.biosci.arizona.edu/cgi-bin";
	my $basePBicon = "http://loco.biosci.arizona.edu/icons";
	
	print $FHRef "Content-type:text/html\n\n";
	print $FHRef <<WEB_HEADER;
		<html>
		<head>
			<title>PhyLoTA: BLAST results</title>
			<link rel="stylesheet" href="$basePBhtml/css/pbmain.css" type="text/css">
		</head>
		<body>
		
			<table>
				<tr>
					<td>
						<a href="/cgi-bin/pb.cgi">
							<img src="/icons/PB_logo.gif"	style="width: 30px; height: 30px;">
						</a>
					</td>
					<td>
						<span style='font-size: 200%; text-align: center; font-weight: bold;'>PhyLoTA: BLAST results</span>
					</td>
				</tr>
			</table>
			<br>
			<div><hr></div>
WEB_HEADER

}

sub printFooter {
	print $FHRef "</body>\n";
	print $FHRef "</html>\n";
}

# return a string in YYYYMMDDHHMISS
sub GetDateTime {
	my (
		$second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings
	  )
	  = localtime();

	my $YY = 1900 + $yearOffset;

	my $MM = $month;
	if ( $month < 10 ) {
		$MM = "0$month";
	}

	my $DD = $dayOfMonth;
	if ( $dayOfMonth < 10 ) {
		$DD = "0$dayOfMonth";
	}

	my $HH = $hour;
	if ( $hour < 10 ) {
		$HH = "0$hour";
	}

	my $TT = $minute;
	if ( $minute < 10 ) {
		$TT = "0$minute";
	}

	my $SS = $second;
	if ( $second < 10 ) {
		$SS = "0$second";
	}

	my $mydatetime = "$YY$MM$DD$HH$TT$SS";    

	return $mydatetime;
}

sub blastSeq {
	my($querySeq, $expect, $maxNumSeq, $wordSize, $matchScore, $gapCost) = @_;
	my %giHash;
	my $prog = 'blastn';
	my $db   = 'nr';

	my @params = ( '-PROGRAM' => $prog,
       '-DATABASE' => $db,
       '-EXPECT' => $expect,
       '-readmethod' => 'SearchIO' );

	my $factory = Bio::Tools::Run::RemoteBlast->new(@params);

	$Bio::Tools::Run::RemoteBlast::HEADER{'HITLIST_SIZE'} = $maxNumSeq;
	$Bio::Tools::Run::RemoteBlast::HEADER{'WORD_SIZE'} = $wordSize;
	$Bio::Tools::Run::RemoteBlast::HEADER{'MATCH_SCORES'} = $matchScore;
	$Bio::Tools::Run::RemoteBlast::HEADER{'GAPCOSTS'} = $gapCost;
	$Bio::Tools::Run::RemoteBlast::RETRIEVALHEADER{'NCBI_GI'} = 'yes';



	if($querySeq){
		#Remove all white spaces, which would cause the query to fail
  		$querySeq =~ s/\s+//g; 


		#Create a query object using the submitted sequence and use that to submit query 
  		my $seq_obj = Bio::Seq->new(-id =>"phylota_seq", -seq =>$querySeq);
 		my $reportObj = $factory->submit_blast($seq_obj);

die "$reportObj\n";

  		#Get an array of records objects
  		while ( my @rids = $factory->each_rid ) {
    		#Iterate through the record objects
    		foreach my $rid ( @rids ) {
      			my $rc = $factory->retrieve_blast($rid);
      			if( !ref($rc) ) {
	    			if( $rc < 0 ) {
						$factory->remove_rid($rid);
        			}
        			sleep 5;
      			} else {

        			my $result = $rc->next_result();
        			#save the output to file
        			#my $filename = $result->query_name()."1.out";
        			#$factory->save_output($filename);

        			$factory->remove_rid($rid);

					#Iterate through hit list and extract GIs
        			while ( my $hit = $result->next_hit ) {
          				my $giValue = "";
          				my $nameStr = $hit->name;
          				my @splitVars = split("[|]", $nameStr);
          				if($splitVars[0] eq "gi") {
          					$giValue = $splitVars[1];
						}
						my $score = $hit->score;
						my $eValue = $hit->significance;
						$giHash{$giValue}{score} = $score;
						$giHash{$giValue}{evalue} = $eValue; 
						#if( my $hsp = $hit->next_hsp ) {
	        			#	my $score = $hsp->score;
	        			#	my $score = $hsp->evalue;
			            #}
						
        			}
      			}
    		}
  		}
	}
	return %giHash;
}

