#!/opt/rocks/bin/perl


use pb;

while (my $fl = shift @ARGV)
  {
  my $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
if (!(-e $configFile))
	{ die "Missing config file pb.conf\n"; }
my %pbH=%{pb::parseConfig($configFile)};
my $release=pb::currentGBRelease();
die "Couldn't find GB release number\n" if (!defined $release);

my $headWorkingDir = $pbH{'HEAD_WORKING_DIR'}; 

$file_cigi="ci_gi_$release";
$file_nodes="nodes_$release";
$file_logs="cluster_logs_$release";

@files=<$headWorkingDir/*nodes*>;
$nFiles=@files;
print "There were $nFiles node files in working directory $headWorkingDir\n";
@files=<$headWorkingDir/*cigi*>;
$nFiles=@files;
print "There were $nFiles cigi files in working directory $headWorkingDir\n";

@files=<$headWorkingDir/*logfile*>;
$nFiles=@files;
print "There were $nFiles logfiles files in working directory $headWorkingDir\n";

$s = "cat $headWorkingDir/*nodes* > $file_nodes";
print "$s\n";
system $s;


$s = "cat $headWorkingDir/*cigi* > $file_cigi";
print "$s\n";
system $s;

$s = "cat $headWorkingDir/*logfile* > $file_logs";
print "$s\n";
system $s;

