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
use strict;
use Getopt::Long;
use Bio::Phylo::PhyLoTA::Config;

##############################
# number of hits reported in any one blast search!!!! Note impact of this on all-all searches
my $blastOutLimit = 250; 
##############################

# process command line arguments
my ( $qfile, $tfile, $outfileStem, $configfile );
GetOptions(
    'qfile=s'      => \$qfile,
    'tfile=s'      => \$tfile,
    'outfile=s'    => \$outfileStem,
    'configfile=s' => \$configfile,
);
my $config = Bio::Phylo::PhyLoTA::Config->new($configfile);
my $release = $config->currentGBRelease();
unless ( $outfileStem && $qfile && $tfile && $configfile ) {
    print "Missing a required command line option\n";
    printUsage();
}
if ( !( -e $qfile && -e $tfile ) ) {
    die("allallblast: input file(s) are missing\n");
}


my $headWorkingDir  = $config->HEAD_WORKING_DIR;
my $slaveWorkingDir = $config->SLAVE_WORKING_DIR;
my $taskId = $ENV{JOB_ID};    # used to provide unique file names
my $outfile    = "$slaveWorkingDir/$outfileStem.$taskId";
my $dbfile     = "$slaveWorkingDir/blastdb.$taskId";
my $fmtlogfile = "$slaveWorkingDir/fmtlog.$taskId";

# Run formatdb prior to blast...
my $blastDir = $config->BLAST_DIR;
my $formatdbCom =
    "$blastDir/bin/formatdb"
  . " -i $tfile"
  . " -l $fmtlogfile"
  . " -p " . $config->PROTEIN_FLAG
  . " -o " . $config->PARSE_SEQID_FLAG
  . " -n $dbfile"; # write the database files to the slave node with this prefix
print "formatting database with: $formatdbCom ($formatdbCom)\n";
system($formatdbCom);
my $blastCom =
    "$blastDir/bin/blastall"
  . " -b $blastOutLimit"
  . " -i $qfile"
  . " -o $outfile"
  . " -e " . $config->BLAST_EXPECT
  . " -F " . $config->BLAST_DUST
  . " -p " . $config->BLAST_PROGRAM
  . " -S " . $config->BLAST_STRAND
  . " -d $dbfile"
  . " -m " . $config->BLAST_OUTPUT_FMT;
print "...$blastCom\n";
print "...running Blast NxN ($blastCom)\n";
system($blastCom);
system "cp $outfile $headWorkingDir\n";
