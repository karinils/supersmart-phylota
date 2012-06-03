# this is a legacy script file from phylota
#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

# process command line arguments
my ( $configFile, $nodeFile, $cigiFile );
GetOptions(
	'config=s' => \$configFile,
	'node=s'   => \$nodeFile,
	'cigi=s'   => \$cigiFile,
);

my $s = "./pb_setup_ci_gi_table_from_file.pl -c $configFile -f $cigiFile";
print "$s...\n";
system $s;

$s = "./pb_setup_node_table_from_file.pl -c $configFile -f $nodeFile";
print "$s...\n";
system $s;

$s = "./pb_setup_clustertable.pl -c $configFile ";
print "$s...\n";
system $s;
