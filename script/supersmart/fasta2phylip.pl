#!/usr/bin/perl
use strict;
use warnings;

my $fasta = shift;
open my $fh, '<', $fasta or die $!;
my %fasta   = simple_fasta( do { local $/; <$fh> } );
my $ntax    = scalar keys %fasta;
my ($nchar) = map { length($_) } values %fasta;

print "$ntax $nchar\n";
for my $defline ( keys %fasta ) {
	if ( $defline =~ /taxon\|(\d+)/ ) {
		my $name = $1;
		print $name, ' ', $fasta{$defline}, "\n";
	}
}

# reads a FASTA string, returns a hash keyed on definition line (sans '>'
# prefix), value is concatenated seq
sub simple_fasta {
    my $string = shift;
    my @lines = split /\n/, $string;
    my %fasta;
    my $current;
    for my $line ( @lines ) {
        chomp $line;
        if ( $line =~ /^>(.+)/ ) {
            $current = $1;
            if ( exists $fasta{$current} ) {
                $fasta{$current} = '';
            }            
        }
        else {
            $fasta{$current} .= $line;
        }
    }
    return %fasta;
}