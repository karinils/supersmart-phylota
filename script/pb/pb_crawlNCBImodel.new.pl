#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -l s_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m e

=pod
# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes

# NB! Make sure all files use naked gi numbers rather than something with e.g., gi#### format.

########### crawlNCBImodel code for cluster use ###########

#		 MJS July 2009
#	Notes: See code for crawlNCBItree.new.pl for the latest on general issues

#	This is a SunGridEngine script (see the first few lines), but can easily be modified to run on anything
#	by changing stuff in the configuration file.

#		This script deals with model organisms as defined in the Phylota Browser, after processing of
#		the non-model taxa's clusters is complete. The basic idea is to avoid the huge computational
#		expense of all-blasting on the order of 500 of these taxa, some of which have hundreds to hundreds of 
#		thousand sequences. This is done with a shortcut. The script looks at clusters that have been already
#		built for neighboring nonmodel taxa, takes a representative of each, and blasts those against the full
#		collection of sequences in the model organisms. This picks up sequences that will be useful in the 
#		context of those outgroups. On the other hand, it will miss sets of homologs that are ONLY found in 
#		some bunch of model organisms in a clade: e.g., homologs between homo and pan will be missed if they
#		are only found in those two large collections of data but are absent from near relatives.
#		Another issue to ponder is that there might be two or more clusters at some internal node from the 
#		original round of clustering that blast to some model org sequence. Technically, these clusters
#		should then be merged, but at the moment, I just arbitrarily place the model seq in one of the clusters.

=cut

use strict;

# .....CAREFUL OF THE NEXT TWO SETTINGS......
#my $watchgi=110189396; # will print out everything that happens to this gi
my $doUpdate =
  1;    # set to 1 to actually update the mysql tables; default doesnt!
my $log      = 0;   # set to 1 to print lots of stuff
my $progress = 1;   # set to 1 to print out which node currently being worked on

# ..........................................
# ...just a place to store these numbers...program uses the last one...
my $tiStart = 53860;    # Coronilla
$tiStart = 71240;       # eudicots
$tiStart = 131567;      # Cellular organisms
$tiStart = 163747;      # Loteae
$tiStart = 3880;        # Medicago truncatula
$tiStart = 7742;        # Vertebrata
$tiStart = 2759;        # Eukaryotes
$tiStart = 163743;      # Vicieae
$tiStart = 6199;        # Cestoda
$tiStart = 3887;        # Pisum
$tiStart = 3877;        # Medicago
$tiStart = 91835;       # Eurosid 1
$tiStart = 4479;        # Poaceae
$tiStart = 20400;       # Astragalus
$tiStart = 3803;        # Fabaceae
$tiStart = 4527;        # Oryza
$tiStart = 4479;        # Poaceae
$tiStart = 3398;        # Angiosperms
$tiStart = 7203;        # Brachycera, for debugging multiple gis problems
$tiStart = 38568;       # Leishmania
$tiStart = 2759;        # eukaryotes

# NEW AND SIMPLIFIED SCHEMA
use POSIX;
use DBI;
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;
$| = 1;    # autoflush
my (%giAddedH);
my $configFile = "/home/sanderm/blast/pb.conf";    #default

while ( my $fl = shift @ARGV ) {
    my $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
    if ( $fl =~ /-t/ ) { $tiStart    = $par; }
}
if ( !( -e $configFile ) ) { die "Missing config file pb.conf\n"; }
my %pbH     = %{ pb::parseConfig($configFile) };
my $release = pb::currentGBRelease();
die "Couldn't find GB release number\n" if ( !defined $release );
my $scriptDir       = $pbH{'SCRIPT_DIR'};
my $slaveDataDir    = $pbH{'SLAVE_DATA_DIR'};
my $slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'};
my ( $saveGI, $saveTI, %tiH );
my $headWorkingDir = $pbH{'HEAD_WORKING_DIR'};
my $taskId = $ENV{JOB_ID};    # used to provide unique file names

# will re-use all of these filenames
my $fastaFile     = "$slaveDataDir/rti$tiStart.fa.id$taskId";
my $qfastaFile    = "$slaveDataDir/rti$tiStart.query.fa.id$taskId";
my $lengthFile    = "$slaveDataDir/rti$tiStart.length.id$taskId";
my $blastout      = "$slaveWorkingDir/rti$tiStart.BLASTOUT.id$taskId";
my $blinkin       = "$slaveWorkingDir/rti$tiStart.BLINKIN.id$taskId";
my $blinkout      = "$slaveWorkingDir/rti$tiStart.BLINKOUT.id$taskId";
my $cigiTableFile = "$slaveWorkingDir/rti$tiStart.cigi.id$taskId"
  ;                           # this will store all the output
my $nodeTableFile = "$slaveWorkingDir/rti$tiStart.nodes.id$taskId"
  ;                           # this will store node table entries for this run
my $clusterTableFile = "$slaveWorkingDir/rti$tiStart.clusters.id$taskId"
  ;    # this will store cluster table entries for this run

# **********************
my $cutoffClusters  = 100;
my $cutoffNumGINode = 10000;    # will cluster a node if < this value
my $cutoffNumGISub  = 35000
  ; # will cluster a subtree if < this value (but these will be nonmodel sequences)
my $cutoffLength = 25000;

# ***********************
# Table names with proper release numbers
my $seqTable     = "seqs";
my $nodeTable    = "nodes" . "\_$release";
my $clusterTable = "clusters" . "\_$release";
my $cigiTable    = "ci_gi_$release";

# ************************************************************
# Read the NCBI names, nodes files...
my ( %sciNameH, %commonNameH );
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/names.dmp";
while (<FH>) {
    my ( $taxid, $name, $unique, $nameClass ) = split '\t\|\t';
    if ( $nameClass =~ /scientific name/ )     { $sciNameH{$taxid}    = $name; }
    if ( $nameClass =~ /genbank common name/ ) { $commonNameH{$taxid} = $name; }
}
close FH;
my ( %ancH, %nodeH, %rankH );
open FH, "<$pbH{'GB_TAXONOMY_DIR'}/nodes.dmp";
while (<FH>) {
    my ( $taxid, $ancid, $rank, @fields ) = split '\t\|\t';
    $ancH{$taxid}  = $ancid;
    $rankH{$taxid} = $rank;
    if ( !exists $nodeH{$ancid} ) { $nodeH{$ancid} = nodeNew($ancid); }
    if ( !exists $nodeH{$taxid} )    # both these exist tests must be present!
    {
        $nodeH{$taxid} = nodeNew($taxid);
    }
    addChild( $nodeH{$ancid}, $nodeH{$taxid} );
}
close FH;

# Get a global list of model taxa
my $dbh = db_connect();
my $sh  = $dbh->prepare("select ti from $nodeTable where model=1");
$sh->execute;
my ( $rowHRef, $ti, %modelH );
while ( $rowHRef = $sh->fetchrow_hashref ) {
    $ti = $rowHRef->{ti};
    $modelH{$ti} = 1;
}
$sh->finish;
$dbh->disconnect;

# Start the recursion at this node
print "Root node for recursion is TI $tiStart\n";
die "root TI $tiStart was missing from node hash...probably deleted from NCBI\n"
  if ( !exists $nodeH{$tiStart} );
my $rootRef = $nodeH{$tiStart};
crawlTree($rootRef);    # discard return values

# *********************************
sub crawlTree {
    my ($nodeRef) = @_;
    my (
        $flagChanges,      %qGiCl,      $sampledGi,    $tiChild,
        $tnChild,          $taxon_name, @allModels,    $ti_anc,
        $ci,               $ci_anc,     $sql,          $sh,
        $i,                $numModels,  $terminalNode, @modelTiList,
        $numDesc,          $descRef,    $ti,           @tis,
        $this_n_clust_sub, $cl,         @existsChildCluster
    );
    $flagChanges = 0
      ; # keep track if there might have been some changes to clusters from model organism hits

    # ...Get some facts about this node
    die
"Invalid or missing node reference passed to crawlTree...probably deleted TI from NCBI\n"
      if ( !defined $nodeRef );
    $ti = $nodeRef->{ID};
    print "Processing node $ti\n" if $progress;
    my $dbh = db_connect();
    $sql = "select ti_anc,taxon_name,n_clust_sub from $nodeTable where ti=$ti;";
    $sh  = $dbh->prepare($sql);
    $sh->execute;

    while ( $rowHRef = $sh->fetchrow_hashref ) {
        $this_n_clust_sub = $rowHRef->{n_clust_sub};
        $ti_anc           = $rowHRef->{ti_anc};
        $taxon_name       = $rowHRef->{taxon_name};
    }
    $sh->finish;

#...store the parent cluster ids of the SUBTREE clusters at each node in an array at that node; will be used in several places
#...N.B. We're only concerned with subtree clusters and their parents in the algorithm below. We don't do any computing directly
#...with node clusters (other than report them).
    $sql =
"select ti_root,ci,ci_anc from $clusterTable where ti_root=$ti and cl_type='subtree';";
    $sh = $dbh->prepare($sql);
    $sh->execute;
    while ( $rowHRef = $sh->fetchrow_hashref ) {
        $ci     = $rowHRef->{ci};
        $ci_anc = $rowHRef->{ci_anc};
        ${ $nodeRef->{PARENT_CL} }[$ci] = $ci_anc
          ; # note this may sometime return as PERL undef if the database has stored a NULL here (as it often does)
    }
    $sh->finish;
    $dbh->disconnect;

# .................................
# BASIC IDEA: Sample every subtree cluster at this internal node (e.g. one per cluster) and set up a query file with these
# sequences. These will then be blasted against a database consisting of the sequences from ALL the model orgs in this subtree.
# The 'easy' but slow way to implement this is to lump all the models (possibly including this node)
# together and blast them, but in many cases the clusters at a node have already been taken care of.
# This happens because (cleverly!), once a hit is found, we
# know this gi will be found in all parent clusters toward the root. Therefore we will propogate those hits toward the root, and
# need not re-blast. Thus, at this point, we check each cluster at the node against its children clusters to see if their parent clusters have already been setup; if so, skip the inclusion of a query sequence for this cluster.
#print "Visiting node $ti ($taxon_name)...\n";
    @allModels = ();
    for $descRef ( @{ $nodeRef->{DESC} } ) {
        $tiChild = $descRef->{ID};
        $tnChild = $sciNameH{$tiChild};

#print "...and recursively visiting its child $tnChild ($tiChild) from parent $taxon_name\n";
        @modelTiList = crawlTree($descRef);

#print "...done visiting child node " . $descRef->{ID} . "from parent $taxon_name: Checking if child subtree has models...\n";
        push @allModels, @modelTiList;
        if ( defined($this_n_clust_sub) ) {
            if ( scalar(@modelTiList) > 0 && $this_n_clust_sub > 0 )

# Proceed only if there actually are some models in this child tree and there are clusters at this ti's node
# (There might not be if it is deep in the tree below a magic node, or if for some reason there were too many
# descendant sequences in all children to cluster)
            {

#print "...........child $tnChild ($tiChild) does have model organisms in its subtree, so set up its parent cluster mapping to see if we should BLAST\n";
                writeSeqs( $cutoffLength, @modelTiList )
                  ; # make the fasta blast database file based on the model ti list
                @existsChildCluster =
                  setupClusterParentArray( $this_n_clust_sub, $descRef );
                if ( -e $qfastaFile ) { system "rm $qfastaFile"; }

# ...get all the right query sequences across the clusters and
# put them in one query file and blast them all at once in once invocation of blast
                open FH,    ">>$qfastaFile";
                open FHlen, ">>$lengthFile"
                  ; # simply append this length info for the query to the database length file; ok for b2b
                %qGiCl = ();
                for $cl ( 0 .. $this_n_clust_sub - 1
                  )   # loop over all the existing subtree clusters at this node
                {
                    if ( !$existsChildCluster[$cl] ) {
                        $sampledGi = appendQfasta( $ti, $cl, $cutoffLength );

 # sample from this cluster in some way and write a query fasta file based on it
                        $qGiCl{$sampledGi} = $cl;
                        $flagChanges = 1;
                    }
                }
                close FH;
                close FHlen;
                blastQ2Model( $ti, \%qGiCl );
            }
            else {

                #print "...........it has no model organisms in its subtree\n";
            }
        }    # end if defined loop
    }    # end descRef loop

#print "Done checking $taxon_name children (recursively)...now checking if $taxon_name is a model organism itself\n";
    if ( $modelH{$ti} ) {

        #print "It is...checking if it is also an internal node\n";
        @modelTiList = ($ti);
        push @allModels, $ti;
        if ( defined($this_n_clust_sub) ) {
            if ( !isTerminal($nodeRef)
                && $this_n_clust_sub >
                0 )    # see comments above about clusters at this node...
            {

#print "Internal node $taxon_name ($ti) is a MODEL and we are proceeding to BLAST its sequences against the subtree clusters at this node already\n";
                writeSeqs( $cutoffLength, @modelTiList )
                  ; # make the fasta blast database file based on the model ti list
                if ( -e $qfastaFile ) { system "rm $qfastaFile"; }

                # ...and again for the internal model
                open FH,    ">>$qfastaFile";
                open FHlen, ">>$lengthFile"
                  ; # simply append this length info for the query to the database length file; ok for b2b
                %qGiCl = ();
                for $cl ( 0 .. $this_n_clust_sub -
                    1 )    # loop over all the existing clusters at this node
                {
                    $sampledGi = appendQfasta( $ti, $cl, $cutoffLength )
                      ; # sample from this cluster in some way and write a query fasta file based on it
                    $qGiCl{$sampledGi} = $cl;
                    $flagChanges = 1;
                }
                blastQ2Model( $ti, \%qGiCl );
                close FH;
                close FHlen;
            }
        }    # end if defined
    }    # end if modelH
    else {

        #print "It is not..\n";
    }
    if ($flagChanges) {
        updateNodeClusters($ti);
    } # change the number of PI clusters in nodes table if they might have changed

    #print "Done with node $taxon_name\n" if ($log);
    return @allModels;
}

# *************************************************
sub blastQ2Model

# Cals qblast to do a blast search of a list of queries (sampled from all the clusters at this node)
# against a database of seqs from model org
# 		$qGiClRef = a ref to a hash that has the cluster for each gi that is in the query file
# ... Main job of this routing is to get the hits for each query/cluster
# and add them to that cluster AND adds them to all parent clusters up toward the root
{
    my ( $ti, $qGiClRef ) = @_;
    my ( $cl, $nodeRef, $hit, $hitsRef, @hits, $tiThis );
    $hitsRef = qblast( $ti, $qGiClRef )
      ;    # execute blast, etc., and get the list of filtered hits
    for $cl ( keys %{$hitsRef} ) {
        @hits = @{ $hitsRef->{$cl} };
        if ( scalar @hits > 0 ) {
            insertHitList( $ti, $cl, @hits )
              ;    # Insert the sequences for this node
            $tiThis = $ti;
            while ( $tiThis != $tiStart
              )    # ...and all its parent clusters up the chain toward the root
            {
                $nodeRef = $nodeH{$tiThis};
                $tiThis  = $ancH{$tiThis};
                $cl      = ${ $nodeRef->{PARENT_CL} }[$cl];
                if ( !defined $cl
                  ) # when we get down to a node with no parents, we can safely stop heading toward root
                {
                    last;
                }
                else # ...but otherwise go ahead and insert the sequences for this node
                {

                    #print "Populating parent cluster at node $ti\n";
                    insertHitList( $tiThis, $cl, @hits );
                }
            }
        }
    }
######  need to update the nodes table and the cluster_table on a change of PI status
    return;
}

sub insertHitList {
    my ( $ti, $cl, @hitList ) = @_;
    my (
        $hit, $s,         $sh,        $n_gi, $n_ti,
        $PI,  $MinLength, $MaxLength, $MaxAlignDens
    );
    my $dbh = db_connect();
    for $hit (@hitList) {
        if ( !( exists $giAddedH{$ti}{$hit} ) )

# IMPORTANT: The following fix ensures that a target hit among a set of model seqs only corresponds
# to one query from one cluster (otherwise it might actually be hit from multiple clusters if the
# target has homology to both...This is a hack; we should merge these clusters but that requires
# an overall rewrite of the algorithm.
# I keep a hash of hashes for model taxa gis that are added to clusters. The basic point is that I don't want any model
# gi to appear in more than one cluster at a node. The set of cluster sets should partition the gis!
# The original solution handled cases in which a model gi blasted to two different clusters in the parent
# node. However, another problematic case is when there are two clusters at the NEXT deeper node. Suppose
# model X (with sequence x) has parent A and grandparent B. A has a parent cluster of X, called CA.
# B has a parent cluster of CA called CB. We discover CA because x blasts to it,  and then we know CB
# is its parent, etc. However, B might also have a DIFFERENT cluster CB* which has homology to X
# (perhaps with different overlap). The program wants to put x in BOTH of these clusters, but we prevent this
# -- completely arbitrarily at the moment. Note that deeper toward the root, the two clusters at C will probably
# merge to the same parent, causing a duplicate gi.
        {
            $giAddedH{$ti}{$hit} = 1
              ; # as we go up toward root we have to keep track of what new hits have been added to clusters
            $s =
"INSERT INTO $cigiTable VALUES($ti, $cl,'subtree',$hit,$tiH{$hit})";
            if ($log)      { print "$s\n" }
            if ($doUpdate) { $dbh->do("$s"); }

        #if ($watchgi==$hit)
        #	{print __LINE__,":Inserting gi$hit into cigiTable ti$ti cluster$cl\n"}
        }
    }

# Sadly, I have to update many of these cluster statistics I've probably already calculated...
# ...Alternatvely I could wait to calculate some of othese until after models are done (?)
    ( $n_gi, $n_ti, $PI, $MinLength, $MaxLength, $MaxAlignDens ) =
      clusterStats( $ti, $cl );
    $s =
"UPDATE $clusterTable set n_gi=$n_gi,n_ti=$n_ti,PI=$PI,MinLength=$MinLength,MaxLength=$MaxLength,MaxAlignDens=$MaxAlignDens where ti_root=$ti and ci=$cl and cl_type='subtree'";
    if ($log)      { print "$s\n" }
    if ($doUpdate) { $dbh->do("$s"); }
    $dbh->disconnect;
}

sub clusterStats

  # returns the number of gi, tis and PI status in a cluster
{
    my ( $ti, $ci ) = @_;
    my ( $rowHRef, $n_gi, $n_ti, $PI, $MinLength, $MaxLength, $MaxAlignDens );
    my $dbh = db_connect();
    my $sql =
"select count($cigiTable.gi) as ngi,count(distinct seqs.ti) as sti,min(length) as MinLength,max(length) as MaxLength, sum(length)/(max(length)*count($cigiTable.gi)) as MaxAlignDens from seqs,$cigiTable where $cigiTable.gi=seqs.gi and $cigiTable.ti=$ti and $cigiTable.clustid=$ci and $cigiTable.cl_type='subtree';";
    my $sh = $dbh->prepare($sql);
    $sh->execute;
    if ( $rowHRef = $sh->fetchrow_hashref ) {
        $n_gi = $rowHRef->{'ngi'};
        $n_ti = $rowHRef->{'sti'};
        if   ( $n_ti >= 4 ) { $PI = 1; }
        else                { $PI = 0; }
        $MinLength    = $rowHRef->{'MinLength'};
        $MaxLength    = $rowHRef->{'MaxLength'};
        $MaxAlignDens = $rowHRef->{'MaxAlignDens'};
    }
    else {
        print "Warning: Cluster not found while updating tables at ti=$ti\n";
    }
    $sh->finish;
    $dbh->disconnect;
    return ( $n_gi, $n_ti, $PI, $MinLength, $MaxLength, $MaxAlignDens );
}

# ****************
# Routine for sampling a cluster to obtain one or more sequences to use as a query, writes query file;
# now just gets longest sequence
# returns gi number of sampled sequences
# The two file handles should be opened and closed prior to first call of this; that way we only open once, etc.
sub appendQfasta {
    my ( $ti, $cl, $cutoffLength ) = @_;
    my ( $sh, $rowHRef, $gi, $seqLen, $seq, $sql );
    my $dbh = db_connect();

    # Following sql command finds the longest gi in the selected cluster
    $sql =
"select seq,clustid,seqs.gi, length from $cigiTable,$seqTable where $cigiTable.ti=$ti and $cigiTable.cl_type='subtree' and clustid=$cl and $seqTable.gi=$cigiTable.gi order by length desc limit 1";
    $sh = $dbh->prepare($sql);
    $sh->execute;
    while ( $rowHRef = $sh->fetchrow_hashref ) {
        $gi     = $rowHRef->{gi};
        $seqLen = $rowHRef->{length};
        $seq    = $rowHRef->{seq};
        print FH ">$gi\n$seq\n";
        print FHlen "$gi\t$seqLen\n";
    }
    $sh->finish;
    $dbh->disconnect;
    return $gi;
}

# **********************************************************
sub updateNodeClusters {
    my ($ti) = @_;
    my ( $sh, $sql, $rowHRef, $count, $countPI, $PI );
    $count = $countPI = 0;
    my $dbh = db_connect();
    $sql =
      "select PI from $clusterTable where ti_root=$ti and cl_type='subtree';";
    $sh = $dbh->prepare($sql);
    $sh->execute;
    while ( $rowHRef = $sh->fetchrow_hashref ) {
        $PI = $rowHRef->{PI};
        ++$count;
        $countPI += $PI;    # adds 1 if its a PI cluster
    }
    $sh->finish;
    $sql =
"UPDATE $nodeTable set n_clust_sub=$count,n_PIclust_sub=$countPI where ti=$ti;";
    if ($log)      { print "$sql\n" }
    if ($doUpdate) { $dbh->do("$sql"); }
    $dbh->disconnect;
}

# **********************************************************
sub setupClusterParentArray

# The PARENT_CL field is obtained from the PB clusters table and is only retrieved for subtree clusters!
# This means any node cluster will have a parent of NULL, so effectively this are disallowed.
{
    my ( $numParentClusters, $childRef ) = @_;
    my ( $i, $parentCluster, $childCluster, @existsChildCluster );
    for $i ( 0 .. $numParentClusters - 1 ) { $existsChildCluster[$i] = 0; }
    for $childCluster ( 0 .. $#{ $childRef->{PARENT_CL} } ) {
        $parentCluster = ${ $childRef->{PARENT_CL} }[$childCluster];
        if (
            defined $parentCluster
          ) # the parent cluster might be undefined if its a NULL in the mysql database
        {

#print "setupParent: child cluster=$childCluster parentCluster=$parentCluster\n";
            $existsChildCluster[$parentCluster] = 1;
        }

#	else {print "setupParent: child cluster=$childCluster parentCluster=undefined\n";}
    }
    return @existsChildCluster;
}

# *************************************************
# for a given list of taxon ids and a seq length cutoff, writes the fasta and length files
# and returns the number of sequences written
# If the taxon list is large, breaks the query into chunks
## SAME FUNCTIONALITY AS writeDBfasta()
sub writeSeqs {
    my ( $lengthCutoff, @tiList ) = @_;
    my (
        $gi,      $ti,         $seq, $numTI,
        $query,   $queryShort, $sql, $sh,
        $rowHRef, $numGI,      $numGIShort
    );
    $numTI = @tiList;
    if ( $numTI == 0 ) { return (0) }
    ; # this happens occasionally if a model node has two model child nodes, for example (I think that's the reason)
    my $chunkSize = 50;
    my $nChunks   = ceil( $numTI / $chunkSize );
    my $remainder = $numTI % $chunkSize;
    my $nSeqs     = 0;
    my $dbh       = db_connect();
    open FH,    ">$fastaFile";
    open FHlen, ">$lengthFile";

    for ( my $chunk = 0 ; $chunk < $nChunks ; $chunk++ ) {
        my $numElem;
        my $first = $chunk * $chunkSize;
        if ( $chunk == $nChunks - 1 )    # i.e., its the last chunk
        {
            if ( $remainder == 0 ) {
                $numElem = $chunkSize;
            }                            # careful of this special case...
            else { $numElem = $remainder }
        }
        else { $numElem = $chunkSize; }
        my @smallTiList = @tiList[ $first .. $first + $numElem - 1 ];
        $queryShort = "length<$lengthCutoff AND (";
        for my $i ( 0 .. $numElem - 2 ) {
            $queryShort .= " ti=$smallTiList[$i] OR ";
        }
        $queryShort .= " ti=$smallTiList[$numElem-1])";
        $sql = "select * from $seqTable where $queryShort;";
        $sh  = $dbh->prepare($sql);
        if ( !$sh ) {
            warn "Database may have evaporated; try reconnecting...";
            db_connect() or warn "Tried reconnecting but failed...\n";
            $sh = $dbh->prepare($sql);
        }
        my $rv = $sh->execute;
        if ( !defined $rv ) {
            warn "Database may have evaporated; trying to reconnect...\n";
            db_connect() or warn "Tried reconnecting but failed...\n";
            $sh = $dbh->prepare($sql);
            $sh->execute;
        }
        while ( $rowHRef = $sh->fetchrow_hashref ) {
            ++$nSeqs;
            $gi       = $rowHRef->{gi};
            $ti       = $rowHRef->{ti};
            $tiH{$gi} = $ti;              # setup this global hash for use later
            my $seqLen = $rowHRef->{length};
            $seq = $rowHRef->{seq};
            print FH ">$gi\n$seq\n";
            print FHlen "$gi\t$seqLen\n";
        }
    }
    close FH;
    close FHlen;
    $sh->finish;
    $dbh->disconnect;
    if ( $nSeqs == 1 ) {
        $saveTI = $ti;
        $saveGI = $gi;
    }    # hack to save some crap below for frequent case of one gi in a taxon
    else { $saveTI = -1; $saveGI = -1; }
    return $nSeqs;
}

# **********************************************************
# Blasts the query file against the database file, expecting that all hits found that pass the blast2blink filter
# will be added to the cluster that the query was sampled from. Therefore we don't call blink at all.
sub qblast {
    my ( $ti, $qGiClRef ) = @_;
    my ( $cl, $gi1, $gi2, %hitgis, %targH );

#system ($blastCom); # note if there are no hits, this writes a file of 0 size in '-m 8' format
#system ("$b2bcmd");
    my $blastDir = $pbH{'BLAST_DIR'};
    my $formatdbCom =
        "$blastDir/bin/formatdb"
      . " -i $fastaFile"
      . " -p $pbH{'PROTEIN_FLAG'}"
      . " -o $pbH{'PARSE_SEQID_FLAG'}";
    my $s = $formatdbCom;
    system($s) == 0 or die "formatdb failed...\n";
    $s =
        "$blastDir/bin/blastall"
      . " -i $qfastaFile"
      . " -o $blastout"
      . " -e $pbH{'BLAST_EXPECT'}"
      . " -F $pbH{'BLAST_DUST'}"
      . " -p $pbH{'BLAST_PROGRAM'}"
      . " -S $pbH{'BLAST_STRAND'}"
      . " -d $fastaFile"
      . " -m $pbH{'BLAST_OUTPUT_FMT'}";

    #print "$s\n";
    system($s) == 0 or die "blastall failed...\n";
    $s =
"$scriptDir/blast2blink.mjs.pl -i $blastout -o $blinkin -t $lengthFile -p $pbH{'OVERLAP_PHI'} -s $pbH{'OVERLAP_SIGMA'} -m $pbH{'OVERLAP_MODE'}\n";

    #print "$s\n";
    system($s) == 0 or die "blast2blink failed...\n";
    if (   -e "$blinkin"
        && -z "$blinkin"
      ) # if the blink file has zero size, there were no hits, so bail without parsing it
    {
        %hitgis = ();
    }
    else {
        open FH, "<$blinkin";
        while (<FH>) {
            ( $gi1, $gi2 ) = /(\d+)\s+(\d+)/;
            $cl = $qGiClRef->{$gi1};
            push @{ $hitgis{$cl} }, $gi2
              ; # this is a hash of arrays: key is the cluster id; array is the list of hit gis
        }
        close FH;
    }
    return \%hitgis;
}

# **********************************************************
sub nodeNew {
    my ($id) = @_;
    return { ID => $id, DESC => [], PARENT_CL => [] };
}

# **********************************************************
sub addChild {
    my ( $nodeRef, $childRef ) = @_;
    push @{ ${$nodeRef}{DESC} }, $childRef;
}

# **********************************************************
sub db_connect {
    my $dbh = DBI->connect(
"DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",
        $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD}
    );
    if ( !defined $dbh )    # try once to reconnect
    {
        warn "My DBI connection failed: trying to reconnect once\n";
        $dbh = DBI->connect(
"DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST};max_allowed_packet=32MB",
            $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD}
        );
    }
    die "My reconnection failed\n" if ( !defined $dbh );
    my $AutoReconnect = 1;
    $dbh->{mysql_auto_reconnect} = $AutoReconnect ? 1 : 0;
    return $dbh;
}

# *************************************************
# for a given list of taxon ids and a seq length cutoff,
# returns the number of sequences written
# If the taxon list is large, breaks the query into chunks
sub countSeqs {
    my ( $lengthCutoff, @tiList ) = @_;
    my (
        $gi,      $ti,         $seq, $numTI,
        $query,   $queryShort, $sql, $sh,
        $rowHRef, $numGI,      $numGIShort
    );
    $numTI = @tiList;
    if ( $numTI == 0 ) { return (0) }
    ; # this happens occasionally if a model node has two model child nodes, for example (I think that's the reason)
    my $chunkSize = 50;
    my $nChunks   = ceil( $numTI / $chunkSize );
    my $remainder = $numTI % $chunkSize;
    my $dbh       = db_connect();
    my $nSeqs     = 0;

    for ( my $chunk = 0 ; $chunk < $nChunks ; $chunk++ ) {
        my $numElem;
        my $first = $chunk * $chunkSize;
        if ( $chunk == $nChunks - 1 )    # i.e., its the last chunk
        {
            if ( $remainder == 0 ) {
                $numElem = $chunkSize;
            }                            # careful of this special case...
            else { $numElem = $remainder }
        }
        else { $numElem = $chunkSize; }
        my @smallTiList = @tiList[ $first .. $first + $numElem - 1 ];
        $queryShort = "length<$lengthCutoff AND (";
        for my $i ( 0 .. $numElem - 2 ) {
            $queryShort .= " ti=$smallTiList[$i] OR ";
        }
        $queryShort .= " ti=$smallTiList[$numElem-1])";
        $sql = "select count(*) as ngi from $seqTable where $queryShort;";
        $sh  = $dbh->prepare($sql);
        if ( !$sh ) {
            warn "Database may have evaporated; try reconnecting...";
            db_connect() or warn "Tried reconnecting but failed...\n";
            $sh = $dbh->prepare($sql);
        }
        my $rv = $sh->execute;
        if ( !defined $rv ) {
            warn "Database may have evaporated; trying to reconnect...\n";
            db_connect() or warn "Tried reconnecting but failed...\n";
            $sh = $dbh->prepare($sql);
            $sh->execute;
        }
        while ( $rowHRef = $sh->fetchrow_hashref ) {
            $nSeqs += $rowHRef->{ngi};
        }
    }
    $sh->finish;
    $dbh->disconnect;
    return $nSeqs;
}

sub isTerminal {
    my ($nodeRef) = @_;
    if   ( scalar @{ $nodeRef->{DESC} } == 0 ) { return 1; }
    else                                       { return 0; }
}
