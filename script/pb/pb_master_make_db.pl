#!/usr/bin/perl -w
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl eq "-c" )     { $configFile = $par; }
    if ( $fl eq "-node" )  { $nodeFile   = $par; }
    if ( $fl eq "-cigi" )  { $cigiFile   = $par; }
    if ( $fl eq "-magic" ) { $magic_file = $par; }
}
die "Configuration file does not exist" if ( !( -e $configFile ) );
$s = "./pb_setup_ci_gi_table_from_file.pl -c $configFile -f $cigiFile";
print "$s...\n";
system $s;
$s = "./pb_setup_node_table_from_file.pl -c $configFile -f $nodeFile";
print "$s...\n";
system $s;
$s = "./pb_setup_clustertable.pl -c $configFile ";
print "$s...\n";
system $s;
$s = "./pb_finalize_node_table.pl -c $configFile -magic $magic_file";
print "$s...\n";
system $s;
$s = "./pb_add_genera_nodestable.pl -c $configFile ";
print "$s...\n";
system $s;
$s = "./pb_add_numgenera_nodestable.pl -c $configFile ";
print "$s...\n";
system $s;

# DON'T DO THE FOLLOWING HERE. WAIT UNTIL AFTER THE MODELS HAVE BEEN ADDED!
#$s = "./pb_add_genera_in_clusters.pl -c $configFile ";
#print "$s...\n";
#system $s;
