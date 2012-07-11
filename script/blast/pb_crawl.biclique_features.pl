#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m a
#$ -o /home/sanderm/blast/SGE_JOBS
# Instead of gis, we use the Phlyota feature IDs everywhere
# sends email only on abort; saves job files in subdirectory
# Note the blastall -b option defaults to 250 sequences returned from the database per query. This is probably ok for
# all-all blasting, but not for single query blasting! How stupid.
# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes
########### crawlNCBI code for cluster use ###########
use Getopt::Long;
use strict;
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
my $biclique_program = "/home/sanderm/bin/bic";
my $configFile       = "/home/sanderm/blast/pb.conf.feature";    #default
my $CDSflag          = 1
  ; # default is to use CDS sequences  ; # = 0, use AA seqs instead (not much point really)
my $cigiDataType = 'cds';        # default data type is cds;
my $mincl        = 0;
my $mintax       = 0;
my $cigiQuery    = "";
my $result       = GetOptions(
    "c=s"      => \$configFile,
    "t=i"      => \$tiStart,
    "mincl=i"  => \$mincl,
    "mintax=i" => \$mintax,
);

#
#  PAY ATTENTION TO THE NEXT LINES !!!!!!!!!!!!
#
if ( $cigiDataType eq
    'ourRNA' )    # handles a special 'or' query for multiple RNA types...
{
    $cigiQuery = "(primary_tag='misc_RNA' OR primary_tag='rRNA')";
}
else { $cigiQuery = "primary_tag='$cigiDataType'"; }
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
my $cigiTableFile = "$slaveWorkingDir/rti$tiStart.cigi.id$taskId"
  ;                           # this will store all the output
my $clusterTableFile = "$slaveWorkingDir/rti$tiStart.clusters.id$taskId"
  ;    # this will store cluster table entries for this run
my $datafile .= "$slaveWorkingDir/bc$tiStart.$taskId";
my $out1 = "$datafile.bc";
my $out2 = "$datafile.bcnum";
my $out3 = "$datafile.bcfiltered";

# Table names with proper release numbers
my $seqTable     = "seqs";
my $featureTable = "features";
my $nodeTable    = "nodes" . "\_$release";

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
my $dbh = db_connect();

# Start the recursion at this node
print "Root node for recursion is TI $tiStart\n";
die "root TI $tiStart was missing from node hash...probably deleted from NCBI\n"
  if ( !exists $nodeH{$tiStart} );
my $rootRef = $nodeH{$tiStart};
crawlTree($rootRef);    # discard return values

#my $s= "cp $cigiTableFile $headWorkingDir\n";
#system $s;
#$s= "cp $nodeTableFile $headWorkingDir\n";
#system $s;
# **********************************************************
sub crawlTree

# for the subtree defined by the arg node, return the number of gis and a list of all tis in the clade, and by the way, do the blast stuff!
# Also, store cluster sets and node info in those two respective mysql tables
{
    my ($nodeRef) = @_;
    die
"Invalid or missing node reference passed to crawlTree...probably deleted TI from NCBI\n"
      if ( !defined $nodeRef );
    my $ti = $nodeRef->{ID};
    print "Processing node $ti\n" if $log;
    my $nQuery = 'subtree';
    open FH, ">$datafile" or die "Could not open $datafile for writing\n";
    my $sql =
"select ti,clustid,ti_of_gi from $clusterTable,$cigiTable where ti_root=$tiNode and PI=1 and $clusterTable.cl_type='$nQuery' and ti=ti_root and ci=clustid";
    my $sh = $dbh->prepare($sql);
    $sh->execute;

    while ( ( $ti, $clustid, $ti_of_gi ) = $sh->fetchrow_array
      )    # only returns one row (presumably) here and next...
    {
        print FH "$clustid\t$ti_of_gi\n";
    }
    $sh->finish;
    close FH;
    $s = "$biclique_program $datafile $out1 $out2";
    print "$s\n";
    system "$s";
## Now parse the output from biclique program
    open FH,    "<$out1" or die "Can't read from $out1\n";
    open FHout, ">$out3" or die "Can't write to $out3\n";

    while (1) {
        last unless ( defined( $line = <FH> ) );
        my @clusters = split ' ', $line;
        last unless ( defined( $line = <FH> ) );
        my @taxa = split ' ', $line;
        last unless ( defined( $line = <FH> ) );
        my $ncl = @clusters;
        my $ntx = @taxa;
        if ( $ncl >= $mincl && $ntx >= $mintax ) {
            print FHout "@clusters\n";
            print FHout "@taxa\n";
        }
    }
    close FH;
    close FHout;
    for $descRef ( @{ $nodeRef->{DESC} } ) {
        crawlTree($descRef);
    }
    return;
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

sub logInfo {
    my $logFile = "$headWorkingDir/rti$tiStart.logfile.id$taskId";
    open FH, ">$logFile";
    my $now_string = localtime;
    print FH "Run date/time  :  $now_string\n";
    print FH "Configuration file  :  $configFile\n";
    print FH "Data type: $cigiDataType\n";
    print FH "Root node of run  :  $tiStart\n";
    print FH "************** Configuration File Options ****************\n";
    foreach ( sort keys %pbH ) { print FH "$_  :  $pbH{$_}\n" }
    print FH "************** OS and SGE Environment ****************\n";
    foreach ( sort keys %ENV ) { print FH "$_  :  $ENV{$_}\n" }
    close FH;
}
