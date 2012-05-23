#!/usr/bin/perl

# Uses mysqldump to obtain a backup of the pb database suitable for recovery elsewhere

$fnprefix = "pb.bu.rel";
while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl =~ /-release/) {$release = $par;}
  }
die "Must specify release number\n" if (!$release);
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$month=$mon+1;
$year+=1900;
$filename = "$fnprefix$release.$month.$mday.$year";
 
$s = "mysqldump -pphylota phylota clusters_$release ci_gi_$release nodes_$release summary_stats seqs > $filename";
print "$s ... \n";
system $s;


