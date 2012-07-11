#!/opt/rocks/bin/perl
#$ -S /opt/rocks/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=2G
#$ -l h_vmem=2G
#$ -M sanderm@email.arizona.edu
#$ -m e
# SGE job to retrieve all pb PI clusters at a node and run Wen-Hsieh Chang's biclique code on it.
# Parses his code's output according to min num taxa and clusters.
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
use DBI;
use pb;
$biclique_program = "/home/sanderm/bin/bic";
$mintax           = 0;
$mincl            = 0;
while ( $fl = shift @ARGV ) {
    if ( $fl eq '-o' )      { $datafile   = shift @ARGV; }
    if ( $fl eq '-c' )      { $configFile = shift @ARGV; }
    if ( $fl eq '-r' )      { $release    = shift @ARGV; }
    if ( $fl eq '-ti' )     { $tiNode     = shift @ARGV; }
    if ( $fl eq '-mincl' )  { $mincl      = shift @ARGV; }
    if ( $fl eq '-mintax' ) { $mintax     = shift @ARGV; }
}

# Initialize a bunch of locations, etc.
%pbH          = %{ pb::parseConfig($configFile) };
$database     = $release;
$cigiTable    = "ci_gi_$release";
$clusterTable = "clusters_$release";
$nQuery       = 'subtree';
my $taskId = $ENV{JOB_ID};    # used to provide unique file names

# Temporary files created with job ids to make them unique to process
$datafile .= ".$taskId";
$out1 = "/home/sanderm/blast/$datafile\.bc";
$out2 = "/home/sanderm/blast/$datafile\.bcnum";
$out3 = "/home/sanderm/blast/$datafile\.bcfiltered";
open FH, ">$datafile" or die "Could not open $datafile for writing\n";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$sql =
"select ti,clustid,ti_of_gi from $clusterTable,$cigiTable where ti_root=$tiNode and PI=1 and $clusterTable.cl_type='$nQuery' and ti=ti_root and ci=clustid";
$sh = $dbh->prepare($sql);
$sh->execute;

while ( ( $ti, $clustid, $ti_of_gi ) =
    $sh->fetchrow_array )   # only returns one row (presumably) here and next...
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
open FHout, ">$out3" or die "Can't read from $out3\n";

while (1) {
    last unless ( defined( $line = <FH> ) );
    @clusters = split ' ', $line;
    last unless ( defined( $line = <FH> ) );
    @taxa = split ' ', $line;
    last unless ( defined( $line = <FH> ) );
    $ncl = @clusters;
    $ntx = @taxa;
    if ( $ncl >= $mincl && $ntx >= $mintax ) {
        print FHout "@clusters\n";
        print FHout "@taxa\n";
    }
}
close FH;
close FHout;
