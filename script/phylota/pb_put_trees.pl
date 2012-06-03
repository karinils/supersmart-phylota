# this is a legacy script file from phylota
#!/usr/bin/perl

# Read a directory full of tree files and insert into the PB database


# CURRENTLY SET TO DO FIX A SPECIFIC SET OF MUSCLE TREES...just uncomment as appropriate

# Also note that in this version I'm expecteding taxon names to be simple gi nums
# If they are giti formatted, uncomment as appropriate

# Read a bunch of tree files; deposit the newick and the consensus fork index (CFI) in mysql


use File::Spec;
use DBI;


use pb;

while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-c/) {$configFile = $par;}
  }
%pbH=%{pb::parseConfig($configFile)};
$release=pb::currentGBRelease();
$clusterTable = "clusters_$release";
my $dbh = DBI->connect("DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",$pbH{MYSQL_USER},$pbH{MYSQL_PASSWD});



$TreeDir = "/var/www/phylota/paupOutput";
$treeField="clustalw_tree";
$resField="clustalw_res";
guts();




sub guts
{
@files = <$TreeDir/*>;


for $file (@files)
	{
	($volume,$infileDir,$infileBase) = File::Spec->splitpath( $file );
	($ti,$cl)=($infileBase=~/ti(\d+)_cl(\d+)/);
	# now read the tree file to parse and get the newick tree (assumes one per file)
	open FH, "<$file";
	while (<FH>)
		{
		if ( ($Tree)=/tree\s+PAUP\_\d+\s*=\s*(?:\[.+\])*\s*(.*);/i)
			{
			$Tree=~s/gi(\d+)\_ti\d+/$1/g;
                	$n_internal=@lparens=($Tree=~m/(\()/g);
                	@taxa=($Tree=~m/(\,)/g);
                	$n_terminal=@taxa+1;
        		$cfi = ($n_internal-1)/($n_terminal-3); # this is the right CFI for an unrooted tree in PAUP with a basal tric
#			print "The edited tree for ti=$ti cl=$cl is $Tree\n";
#			print "CFI=$cfi\n"; 
			$s="update $clusterTable set $treeField=\'$Tree\',$resField=$cfi where ti_root=$ti and ci=$cl and cl_type='subtree'"; 
#			print "$s\n";
			$dbh->do($s);
			}
		}
	close FH;
	++$count;
#	die if ($count>10);
	}
}
