#!/opt/rocks/bin/perl

# paste all the files from the directory (and its subdirectories) into a single two col file with filename and tree description
# suitable for import into phylota



$treesDir = "/redwood/export/mcmahonm/pb184/raxml_trees_muscle_184";

use pb;

while (my $fl = shift @ARGV)
  {
  my $par = shift @ARGV;
  if ($fl =~ /-o/) {$outfile = $par;}
  }
if (!$outfile)
	{ die "Missing outfile\n"; }

open FH, ">$outfile";

for $i (1..9)
	{
	$wDir = "$treesDir/ti$i" . "xx";
	opendir(DIR,$wDir) or die "Failed to open directory $wDir\n"; 
	while ($file = readdir(DIR))
		{
		next if ($file !~ /RAxML_bestTree/);
		($newfn) = ($file =~ /(RAxML.*phy)/);
		$tree = `cat $wDir/$file`;
		chomp $tree;
		print FH "$newfn\t$tree\n";
		}
	closedir DIR;	
	}
close FH;
