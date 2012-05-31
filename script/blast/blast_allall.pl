#!/opt/rocks/bin/perl -w
#$ -S /opt/rocks/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=3G
#$ -l h_vmem=3G
#$ -l s_vmem=3G
#$ -M sanderm@email.arizona.edu
#$ -m a
#$ -o /home/sanderm/blast/SGE_JOBS
# ### NB! "FIXED" on April12,2011 to allow true mxn blast. Had just allowed nxn blast.
# Careful of what happens to tfile and qfile...
# Generic SGE script to do all against all BLAST using a Phylota Browser style config file but user supplied inputs on
# the qsub command line...(see below for syntax of command line args); can also use it to blast one file against another...
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use pb;
##############################
$blastOutLimit = 250
  ; # number of hits reported in any one blast search!!!! Note impact of this on all-all searches
##############################
$ARGC = @ARGV;
if ( $ARGC == 0 ) { printUsage(); }
while ( $fl = shift @ARGV ) {
    $option = shift @ARGV;
    if ( $fl =~ /-q/ ) { $qfileName   = $option; }
    if ( $fl =~ /-t/ ) { $tfileName   = $option; }
    if ( $fl =~ /-o/ ) { $outfileName = $option; }
    if ( $fl =~ /-c/ ) { $configFile  = $option; }
}
%pbH     = %{ pb::parseConfig($configFile) };
$release = pb::currentGBRelease();
if (   $outfileName eq ""
    || $qfileName  eq ""
    || $tfileName  eq ""
    || $configFile eq "" )
{
    print "Missing a required command line option\n";
    printUsage();
}
if ( !( -e $qfileName && -e $tfileName ) ) {
    die("allallblast: input file(s) are missing\n");
}
$headWorkingDir  = $pbH{'HEAD_WORKING_DIR'};
$slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'};
my $taskId = $ENV{JOB_ID};    # used to provide unique file names
my $outfile    = "$slaveWorkingDir/$outfileName.$taskId";
my $dbfile     = "$slaveWorkingDir/blastdb.$taskId";
my $fmtlogfile = "$slaveWorkingDir/fmtlog.$taskId";

# Run formatdb prior to blast...
$blastDir = $pbH{'BLAST_DIR'};
$formatdbCom =
    "$blastDir/bin/formatdb"
  . " -i $tfileName"
  . " -l $fmtlogfile"
  . " -p $pbH{'PROTEIN_FLAG'}"
  . " -o $pbH{'PARSE_SEQID_FLAG'}"
  . " -n $dbfile"; # write the database files to the slave node with this prefix
print "formatting database with: $formatdbCom ($formatdbCom)\n";
system($formatdbCom);
$blastCom =
    "$blastDir/bin/blastall"
  . " -b $blastOutLimit"
  . " -i $qfileName"
  . " -o $outfile"
  . " -e $pbH{'BLAST_EXPECT'}"
  . " -F $pbH{'BLAST_DUST'}"
  . " -p $pbH{'BLAST_PROGRAM'}"
  . " -S $pbH{'BLAST_STRAND'}"
  . " -d $dbfile"
  . " -m $pbH{'BLAST_OUTPUT_FMT'}";
print "...$blastCom\n";
print "...running Blast NxN ($blastCom)\n";
system($blastCom);
system "cp $outfile $headWorkingDir\n";
