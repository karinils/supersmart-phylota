#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m a
#$ -o /home/sanderm/blast/SGE_JOBS
#### This is the CDS cluster version NOVEMBER 2010 MJS ####
# sends email only on abort; saves job files in subdirectory
# Takes any sequence record with an AA translation, gets the CDS feature and uses it in usual all-all blast
# Notice the usual seq length cutoff still applies, but won't ever be an issue since now it is the length of
# AA sequence that is being measured in that part of code
#####
# Note the blastall -b option defaults to 250 sequences returned from the database per query. This is probably ok for
# all-all blasting, but not for single query blasting! How stupid.
# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes
########### crawlNCBI code for cluster use ###########
use Getopt::Long;
use strict;
use Bio::Seq;
use Bio::SeqFeature::Generic;
use Bio::Factory::FTLocationFactory;
use POSIX;
use DBI;
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;
my $log = 0;    # set to 1 to log lots of stuff

# ...just a place to store these numbers...program uses the last one...
my $tiStart = 53860;    # Coronilla
$tiStart = 71240;       # eudicots
$tiStart = 3880;        # Medicago truncatula
$tiStart = 163743;      # Vicieae
$tiStart = 4527;        # Oryza
$tiStart = 3887;        # Pisum
$tiStart = 3877;        # Medicago
$tiStart = 4479;        # Poaceae
$tiStart = 20400;       # Astragalus
$tiStart = 3803;        # Fabaceae
$tiStart = 163747;      # Loteae
$|       = 1;           # autoflush
my $configFile = "/home/sanderm/blast/pb.conf.cds";    #default
my $CDSflag    = 1
  ; # default is to use CDS sequences  ; # = 0, use AA seqs instead (not much point really)
my $result = GetOptions(
    "c=s" => \$configFile,
    "t=i" => \$tiStart
);
if ( !( -e $configFile ) ) { die "Missing config file pb.conf\n"; }
print "Using configuration file $configFile\n";
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
my $cutoffClusters = $pbH{'cutoffClusters'};
my $cutoffNumGINode =
  $pbH{'cutoffNumGINode'};    # will cluster a node if < this value
my $cutoffNumGISub = $pbH{'cutoffNumGISub'
  }; # will cluster a subtree if < this value (but these will be nonmodel sequences)
my $cutoffLength = $pbH{'cutoffLengthFeatures'
  };    # here the relevant cutoff length is for the feature
die "Cutoff parameters not provided in config files\n"
  if ( !$cutoffClusters
    || !$cutoffNumGINode
    || !$cutoffNumGISub
    || !$cutoffLength );

# ***********************
# Table names with proper release numbers
my $seqTable  = "seqs";
my $aaTable   = "aas";
my $nodeTable = "nodes" . "\_$release";

# ***********************
my $cigiDataType =
  'cds';    # this value will now be put into the cigi table do indicate type

# ***********************
logInfo();    # write the log file

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

# Start the recursion at this node
print "Root node for recursion is TI $tiStart\n";
die "root TI $tiStart was missing from node hash...probably deleted from NCBI\n"
  if ( !exists $nodeH{$tiStart} );
my $rootRef = $nodeH{$tiStart};
crawlTree($rootRef);    # discard return values
my $s = "cp $cigiTableFile $headWorkingDir\n";
system $s;
$s = "cp $nodeTableFile $headWorkingDir\n";
system $s;

# **********************************************************
sub crawlTree

# for the subtree defined by the arg node, return the number of gis and a list of all tis in the clade, and by the way, do the blast stuff!
# Also, store cluster sets and node info in those two respective mysql tables
{
    my ($nodeRef) = @_;
    die
"Invalid or missing node reference passed to crawlTree...probably deleted TI from NCBI\n"
      if ( !defined $nodeRef );
    my (
        $terminalNode, $dummy,     $modelFlag,
        $length,       @tiList,    $numGI,
        $numGISub,     $numGIThis, $numGIThisShort,
        $numTI,        $numDesc,   $numGIDesc,
        $descRef,      $ti,        $numSeq,
        $ngi,          $nsp,       $nodeAlreadyExists
    );
    my (
        $query,               $gi_node,          $gi_sub_nonmodel,
        $gi_sub_model,        $numCl_node,       $numCl_PI_node,
        $numCl_sub,           $numCl_PI_sub,     $nspDesc,
        $nspModel,            $nodeIsClustered,  $this_n_clust_node,
        $this_n_PIclust_node, $this_n_clust_sub, $this_n_PIclust_sub,
        $nodeWasProcessed
    );

    # ...take care of this NODE
    $ti = $nodeRef->{ID};
    print "Processing node $ti\n" if $log;
    push @tiList, $ti;
    $nspDesc       = 0;
    $nspModel      = 0;
    $numGIDesc     = 0;
    $numGIThis     = 0;
    $numGISub      = 0;
    $numCl_node    = 0;
    $numCl_PI_node = 0;
    $numCl_sub     = 0;
    $numCl_PI_sub  = 0;
    my $n_leaf_desc = 0;
    my $n_node_desc = 0;    # "otu's" these are nodes WITH ANY sequences...
    if   ( 0 == scalar @{ $nodeRef->{DESC} } ) { $terminalNode = 1; }
    else                                       { $terminalNode = 0; }
    my $rank     = $rankH{$ti};
    my $anc      = $ancH{$ti};
    my $rankFlag = 0;
    my ( $comName, $sciName, $rankName );

    if (   $rank eq "genus"
        || $rank eq "species"
        || $rank eq "subspecies"
        || $rank eq "varietas"
        || $rank eq "subgenus"
        || $rank eq "forma" )
    {
        $rankFlag = 1;
    }    # used for italics in HTML
    else { $rankFlag = 0; }
    if   ( exists $commonNameH{$ti} ) { $comName = $commonNameH{$ti}; }
    else                              { $comName = ""; }

    # CRAZY TO DO THIS -- FIX AFTER CHECKING BEHAVIOR
    my $dbh = db_connect();
    $comName  = $dbh->quote($comName);
    $sciName  = $dbh->quote( $sciNameH{$ti} );
    $rankName = $dbh->quote($rank);
    $dbh->disconnect;

    # First, handle the BLAST for the node clusters
    $gi_node = countSeqs( $cutoffLength, @tiList )
      ;    # we will continue to exclude seqs >= to this length

# NB. This length is in residues of the AA seqs for this CDS run, so normally will never matter
    $numGI = $gi_node;
    if ( $numGI >=
        $cutoffNumGINode ) # This is a model organism by definition, don't BLAST
    {
        $modelFlag = 1;
        $nspModel  = 1;
        pop @tiList;  # get rid of this node before doing the subtree clustering
        $gi_sub_model    = $gi_node;
        $gi_sub_nonmodel = 0;
    }
    else # ... BLAST cluster this and note if its a model org by having too many clusters
    {
        ($numCl_node) =
          blastCluster( $gi_node, $cutoffLength, $tiStart, $ti, 'node',
            $cigiDataType, @tiList );
        if ( $numCl_node < $cutoffClusters
          )    # ...and there were few enough clusters to call it a nonmodel org
        {
            $modelFlag       = 0;
            $gi_sub_nonmodel = $gi_node;
            $gi_sub_model    = 0;
        }
        else    # ...or a model org
        {
            $modelFlag = 1;
            $nspModel  = 1;
            pop @tiList
              ;    # get rid of this node before doing the subtree clustering
            $gi_sub_model    = $gi_node;
            $gi_sub_nonmodel = 0;
        }
    }

# ...Second, handle the subtree clusters, which include all sequences at this node plus all descendant nodes.
# Done by postorder traversal. We have to get all the descendant's tis to do the clustering for THIS subtree.
    for $descRef ( @{ $nodeRef->{DESC} } ) {
        my ( $n1, $n2, $s1, $s2, $s3, $s4, @tis ) = crawlTree($descRef);
        push @tiList, @tis;
        $gi_sub_nonmodel += $n1;
        $gi_sub_model    += $n2;
        $nspDesc         += $s1;
        $nspModel        += $s2;
        $n_leaf_desc     += $s3;
        $n_node_desc     += $s4;    # these are OTUs (i.e. nodes with sequences)
    }

# on this blast cluster we don't need the first two returned values; they've already been set above
    if ( !$terminalNode
      )    # no sense blasting AGAIN for this node when its terminal!
    {
        $numGI = $gi_sub_nonmodel;

# NB! I can no longer trust
# the @tiList; I've put in a shortcut that zeros out that array when the num seqs is so large that we aren't gonna
# cluster it anyway. Eventually rewrite numGIsql...
        if ( $numGI < $cutoffNumGISub ) {
            ($numCl_sub) =
              blastCluster( $numGI, $cutoffLength, $tiStart, $ti, 'subtree',
                $cigiDataType, @tiList );
        }
    }
    if ( $numGI >= $cutoffNumGISub ) {
        @tiList =
          ();    # saves the effort of returning a possibly large array when
                 # it won't be clustered deeper in the tree anyway
    }

# By placing the following lines *after* storing the value for the node, we enforce the convention that
# taxon counts never include the current node, only the descendants
    if ( $rank eq "species" ) { $nspDesc = 1; }
    if ($terminalNode) { $n_leaf_desc = 1; }
    if ( $gi_node > 0 ) { ++$n_node_desc; }

# All the variables are stored correctly EXCEPT the following does NOT store the two fields for number of PI clusters;
# just stores a 0 instead. This will have to be fixed in a later mysql script. Clunky to do it here.
# Gotcha! Notice that nodes can't have PI clusters, so I don't need that field, do I?
    open FHnodes, ">>$nodeTableFile"
      or print "Couldn't open node table file for append at ti=$ti";

#print FHnodes "$ti\t$anc\t$terminalNode\t$rankFlag\t$modelFlag\t$sciName\t$comName\t$rankName\t$gi_node\t$gi_sub_nonmodel\t$gi_sub_model\t$numCl_node\t$numCl_sub\t$numCl_PI_sub\t$nspDesc\t$nspModel\t$n_leaf_desc\t$n_node_desc\n";
# Notice the \N is written so mysql will read it as a NULL in its load statement (their convention): i.e., I do not keep anything about cluster numbers
    print FHnodes
"$ti\t$anc\t$terminalNode\t$rankFlag\t$modelFlag\t$sciName\t$comName\t$rankName\t$gi_node\t$gi_sub_nonmodel\t$gi_sub_model\t\\N\t\\N\t\\N\t$nspDesc\t$nspModel\t$n_leaf_desc\t$n_node_desc\n";
    close FHnodes;
    return ( $gi_sub_nonmodel, $gi_sub_model, $nspDesc, $nspModel, $n_leaf_desc,
        $n_node_desc, @tiList );
}

# *************************************************
# for a given list of taxon ids and a seq length cutoff, writes the fasta and length files
# and returns the number of sequences written
# If the taxon list is large, breaks the query into chunks
sub writeSeqs {
    my ( $lengthCutoff, @tiList ) = @_;
    my (
        $gi,      $gi_aa, $length_aa,  $ti,  $seq,
        $numTI,   $query, $queryShort, $sql, $sh,
        $rowHRef, $numGI, $numGIShort
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
        $sql =
"select ti,gi_aa,length_aa,seq_aa from $aaTable,$seqTable where seqs.gi=aas.gi and $queryShort;";
        print "$sql\n" if $log;
        $sh = $dbh->prepare($sql);
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
            $gi       = $rowHRef->{gi_aa};
            $ti       = $rowHRef->{ti};
            $tiH{$gi} = $ti;              # setup this global hash for use later
            my ( $seq, $seqLen, $dummy );
            if ($CDSflag) {
                ( $seq, $dummy ) = extract_CDS($gi);
                $seqLen = length($seq);
            }
            else {
                $seqLen = $rowHRef->{length_aa};
                $seq    = $rowHRef->{seq_aa};
            }
            if ( $seqLen > 0
              ) # possible that extraction of CDS failed or something else went awry
            {
                print FH ">$gi\n$seq\n";
                print FHlen "$gi\t$seqLen\n";
            }
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

# *************************************************
sub blastCluster {
    my (
        $numGI,   $cutoffLength, $root_ti, $cur_ti,
        $cl_type, $cigiDataType, @tiList
    ) = @_;
    my (
        $seqLen,  $ti, $numGIcl, $numTI, $numCl, $sql, $sh,
        $rowHRef, $gi, $def,     $seq,   $cl,    $i
    );
    my ( $clusterID, $s );
    $numTI = @tiList;
    writeSeqs( $cutoffLength, @tiList );
    print
"Beginning all-all blast ($cl_type): ti$cur_ti ($sciNameH{$cur_ti})\tngi=$numGI\tnti=$numTI\n"
      if ($log);
    if ( $numGI == 0 ) { return (0); }
    if ( $numGI == 1
      ) # simple special case of one GI (it happens a lot) .. use values saved at end of fetchSeqs..
    {
        open FHfcf, ">>$cigiTableFile"
          or print "Couldn't open final cluster file for append at ti=$cur_ti";
        print FHfcf "$cur_ti\t0\t$cl_type\t$cigiDataType\t$saveGI\t$saveTI\n"
          ;    # writes to file handled opened before recursion
        close FHfcf;
        $numCl = 1;
    }
    else {

      # Now do the actual all all BLAST, and subsequent processing through blink
        my $blastDir = $pbH{'BLAST_DIR'};
        my $formatdbCom =
            "$blastDir/bin/formatdb"
          . " -i $fastaFile"
          . " -p $pbH{'PROTEIN_FLAG'}"
          . " -o $pbH{'PARSE_SEQID_FLAG'}";
        $s = $formatdbCom;
        system($s) == 0 or die "formatdb failed...\n";
        $s =
            "$blastDir/bin/blastall"
          . " -i $fastaFile"
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
        $s = "$scriptDir/blink -i $blinkin -c > $blinkout\n";

        #print "$s\n";
        system($s) == 0 or die "blink failed...\n";
        open FHfcf, ">>$cigiTableFile"
          or print "Couldn't open final cluster file for append at ti=$cur_ti";
        open FH, "<$blinkout"
          or print "Couldn't open BLINKOUT file $blinkout for re-reading\n";
        $cl = -1
          ; # in case the next file is empty, we'll return the fact that there are 0 clusters this way
        while (<FH>) {
            ( $cl, $gi ) = split;
            print FHfcf
              "$cur_ti\t$cl\t$cl_type\t$cigiDataType\t$gi\t$tiH{$gi}\n";
        }
        close FH;
        close FHfcf;
        $numCl = $cl + 1;    # assuming cl ids are on 0...n-1
             #  Following removes the sometimes very large BLAST output files...
        if ( -e $blastout ) { unlink $blastout }
    }    # end else from above
    return ($numCl);
}

# **********************************************************
sub nodeNew {
    my ($id) = @_;
    return {
        ID                      => $id,
        DESC                    => [],
        NUMSEQ                  => 0,
        NUMDESCSEQ              => 0,
        NUMDESCSEQNONMODEL      => 0,
        NUMDESCSPECIES          => 0,
        NUMDESCSEQNODES         => 0,
        NUMDESCSEQNODESNONMODEL => 0,
        NUMSEQTOTAL             => 0,
        NUMSEQTOTALNONMODEL     => 0
    };
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
        $sql =
"select count(*) as ngi from $aaTable,$seqTable where seqs.gi=aas.gi and $queryShort;";
        $sh = $dbh->prepare($sql);
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

# Extracts from the PB the DNA sequence corresponding to an AA translation.
# The "range" specifier together with "codon_start" tells us how to deal with this stuff.
# The prefix is handled via codon_start. I handle the suffix by merely removing anything after
# an even multiple of 3 at the end.
# NB. NCBI's translations remove the stop codon and hence are one triplet shorter than the DNA
# ranges suggest. I check for terminal codons TAA TAG TGA and delete them if present
# An NCBI gotcha: sometimes they will deduce the last AA even based on only two nucleotides if that is possible
# from the genetic code. This is another reason the dna lengths and aa lengths are not predictable from each other.
# Try ignoring this and see if tranalign will handle ok if I just remove stop codons from dna
sub extract_CDS {
    my ($gi_aa) = @_;         # starting with the AA gi
    my $dbh = db_connect();
    my $sql =
"select gi, length_aa, codon_start, range, transl_table from aas where gi_aa=$gi_aa";
    my $sh = $dbh->prepare($sql);
    $sh->execute;
    my ( $gi, $length_aa, $codon_start, $range, $transl_table ) =
      $sh->fetchrow_array;    # get the AA stuff
    $sql = "select length, seq from seqs where gi=$gi";    # now get the DNA CDS
    $sh  = $dbh->prepare($sql);
    $sh->execute;
    my ( $length_dna, $seq_dna ) =
      $sh->fetchrow_array;  # only returns one row (presumably) here and next...
    my ( $CDS_dna, $CDS_aa ) =
      extract_CDS_bioperl( $gi_aa, $range, $codon_start, $transl_table,
        $seq_dna );
    return ( $CDS_dna, $CDS_aa );
}

sub extract_CDS_bioperl {
    my ( $gi_aa, $range, $codon_start, $transl_table, $seqin ) = @_;
    my ($frame)     = $codon_start - 1;    # convention in bioperl vs ncbi
    my $trimmed_dna = "";
    my $trimmed_aa  = "";
    if ( !defined $transl_table ) { $transl_table = 1 }
    ;                                      # enforce default translation table
    eval {
        my $nuc_obj = Bio::Seq->new(
            -display_id => 'temporary',
            -seq        => $seqin,
            -alphabet   => 'dna'
        );

# ...BioPerl bug: complains if I don't add the display id, but only for 'join(...)' locations!
        my $loc_factory = Bio::Factory::FTLocationFactory->new;
        my $loc_object  = $loc_factory->from_string($range);
        my $feat_obj    = Bio::SeqFeature::Generic->new(
            -location => $loc_object,
            -frame    => $frame
        );
        $nuc_obj->add_SeqFeature($feat_obj);
        my $cds_obj         = $feat_obj->spliced_seq;
        my $cds_dna         = $cds_obj->seq;
        my $trimmed_dna_obj = $cds_obj->trunc( $codon_start, $cds_obj->length );
        my $xlength         = $trimmed_dna_obj->length;
        my $remainder       = $xlength % 3;

        if ( $remainder !=
            0 )  # if there is a partial codon at the end of sequence, remove it
        {
            $trimmed_dna_obj =
              $trimmed_dna_obj->trunc( 1, $xlength - $remainder );
        }
        $trimmed_aa =
          $trimmed_dna_obj->translate( -codontable_id => $transl_table )->seq;
        if ( $trimmed_aa =~ /\*$/
          )   # if the last codon is a stop, then delete this codon from dna seq
        {
            $trimmed_dna_obj = $trimmed_dna_obj->trunc( 1, $xlength - 3 );
            $trimmed_aa = substr( $trimmed_aa, 0, -1 );
        }
        $trimmed_dna = $trimmed_dna_obj->seq;
        if ( length($trimmed_dna) != 3 * length($trimmed_aa) ) {
            die "Mismatch count between dna and aa\n";
        }
        1;
    } or do {    # caught a BioPerl exception: probably some fucked up sequence
        warn
"Bio Perl CDS extraction failed for sequence gi_aa$gi_aa: range $range, frame: $codon_start\n$seqin\n";
        print "BioPerl message was:\n$@\n";
    };
    return ( $trimmed_dna, $trimmed_aa );
}

sub logInfo {
    my $logFile = "$headWorkingDir/rti$tiStart.logfile.id$taskId";
    open FH, ">$logFile";
    my $now_string = localtime;
    print FH "Run date/time  :  $now_string\n";
    print FH "Configuration file  :  $configFile\n";
    print FH "Data type: $cigiDataFile\n";
    print FH "Root node of run  :  $tiStart\n";
    print FH "************** Configuration File Options ****************\n";
    foreach ( sort keys %pbH ) { print FH "$_  :  $pbH{$_}\n" }
    print FH "************** OS and SGE Environment ****************\n";
    foreach ( sort keys %ENV ) { print FH "$_  :  $ENV{$_}\n" }
    close FH;
}
