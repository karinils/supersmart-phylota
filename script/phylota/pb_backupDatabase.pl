# this is a legacy script file from phylota
#!/usr/bin/perl
use strict;
use Getopt::Long;
# Uses mysqldump to obtain a backup of the pb database suitable for recovery elsewhere

my $fnprefix = "pb.bu.rel";
my $release;
GetOptions(
	'release=s'  => \$release,
	'fnprefix=s' => \$fnprefix,
);

die "Must specify release number\n" if (!$release);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $month=$mon+1;
$year+=1900;
my $filename = "$fnprefix$release.$month.$mday.$year";
 
my $s = "mysqldump -pphylota phylota clusters_$release ci_gi_$release nodes_$release summary_stats seqs > $filename";
print "$s ... \n";
system $s;


