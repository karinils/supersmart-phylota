#!/usr/bin/perl

# Submits a bunch of pb_crawlNCBI jobs to the cluster, one for each taxon id node listed in the table infile
# That file expects tab delim table in which the ti is the first column.


while (my $fl = shift @ARGV)
  {
  my $par = shift @ARGV;
  if ($fl =~ /-f/) {$infile = $par;}
  }

open FH, "<$infile";
while (<FH>)
	{
	@cols=split;
	push @tis, $cols[0];
	}

for $ti (@tis)	

	{
	$s=" qsub pb_crawlNCBI.new.pl -t $ti -c pb.conf";
	print "$s\n";
	system $s;
	}
