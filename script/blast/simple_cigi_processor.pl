#!/opt/rocks/bin/perl
# Note the above required to get the version that has bioperl libs

# Input: default is a two-column tab delim table with clusterid and taxon_label
# but if -single_cluster is set, then just a one column table with taxon_label
# Taxon label MUST have /gi(\d+)/ at the beginning of the label--before the first white space which is split on

# Filtering by min number of unambiguous sites is done first; then by excluded taxon name; only then is grouping
# by TI or genus done on the basis of max number of unambig sites. [all optionally of course]


while ($fl = shift @ARGV)
  {
  if ($fl eq '-f') {$inFile = shift @ARGV;} # cigi file
  }

open FH, "<$inFile";
while (<FH>)
	{
	chomp;
	($cl,$label)=/(\d+)\s+(.*)/;
	push @{ $cigi[$cl] }, $label;
	}
$max=0;
for $cl (0..$#cigi)
{
my @labels = @{$cigi[$cl]};
$numSeqs   = @labels;
if ($numSeqs > $max) {$max = $numSeqs}
if ($numSeqs == 1) { ++$numSingleton }
if ($numSeqs < 4) {
	++$countNumUn;
	$numUn += $numSeqs;
	}
print "$cl\t$numSeqs\n";
}

print "Size of largest cluster:$max\n";
print "Number of clusters < 4 taxa:$countNumUn\n";
print "Total number of sequence in uninformative clusters:$numUn\n";
print "Number of singleton clusters = $numSingleton\n";
