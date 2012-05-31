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
    if ( $fl =~ /-l/ ) { $lengthFile  = $option; }
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
$scriptDir       = $pbH{'SCRIPT_DIR'};
$slaveDataDir    = $pbH{'SLAVE_DATA_DIR'};
$slaveWorkingDir = $pbH{'SLAVE_WORKING_DIR'};
$headWorkingDir  = $pbH{'HEAD_WORKING_DIR'};
my $taskId = $ENV{JOB_ID};    # used to provide unique file names
my $outfile = "$slaveWorkingDir/$outfileName.$taskId";

# $lengthFile="$slaveDataDir/$fileNamePrefix.length";
# Run formatdb prior to blast...
$blastDir = $pbH{'BLAST_DIR'};
$formatdbCom =
    "$blastDir/bin/formatdb"
  . " -i $tfileName"
  . " -p $pbH{'PROTEIN_FLAG'}"
  . " -o $pbH{'PARSE_SEQID_FLAG'}"
  . " -n $slaveDataDir/blastdb"
  ;    # write the database files to the slave node with this prefix
print "formatting database with: $formatdbCom ($formatdbCom)\n";
system($formatdbCom);

# Do the all-by-all blast regardless of startover status from here on
$blastCom =
    "$blastDir/bin/blastall"
  . " -b $blastOutLimit"
  . " -i $qfileName"
  . " -o $outfile"
  . " -e $pbH{'BLAST_EXPECT'}"
  . " -F $pbH{'BLAST_DUST'}"
  . " -p $pbH{'BLAST_PROGRAM'}"
  . " -S $pbH{'BLAST_STRAND'}"
  . " -d $slaveDataDir/blastdb"
  .    # using a simple name always for the database file
  " -m $pbH{'BLAST_OUTPUT_FMT'}";
print "...$blastCom\n";
print "...running Blast NxN ($blastCom)\n";
system($blastCom);

#system "$scriptDir/blast2blink.mjs.pl -i $outfile -o $outfile\_BLINKIN -t $lengthFile -p $pbH{'OVERLAP_PHI'} -s $pbH{'OVERLAP_SIGMA'} -m $pbH{'OVERLAP_MODE'}\n";
system "$scriptDir/blast2BlinkSimple.pl -i $outfile -o $outfile\_BLINKIN \n";
system "$scriptDir/blink -i $outfile\_BLINKIN -c > $outfile\_BLINKOUT\n";
system "cp $outfile\_BLINKOUT $headWorkingDir\n";
system "cp $outfile $headWorkingDir\n";

sub printUsage {
    die
"generic_all_all.pl -q queryfile -t targetfile -o outputfile -c pb config file -l lengthfile\n";
}
