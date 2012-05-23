#!/usr/bin/perl -w



while ($fl = shift @ARGV)
  {
  $par = shift @ARGV;
  if ($fl  eq "-c") {$configFile = $par;}
  if ($fl  eq "-node") {$nodeFile= $par;}
  if ($fl  eq "-cigi") {$cigiFile= $par;}
  }

$s = "./pb_setup_ci_gi_table_from_file.pl -c $configFile -f $cigiFile";
print "$s...\n";
system $s;
$s = "./pb_setup_node_table_from_file.pl -c $configFile -f $nodeFile";
print "$s...\n";
system $s;
$s = "./pb_setup_clustertable.pl -c $configFile ";
print "$s...\n";
system $s;
