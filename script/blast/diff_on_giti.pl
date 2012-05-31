#!/usr/bin/perl
open FH1, "<$ARGV[0]";
open FH2, "<$ARGV[1]";
while (<FH1>) {
    if ( ( $gi, $ti ) = /gi(\d+)_ti(\d+)/ ) { $seq1H{$ti} = $gi; }
}
close FH1;
while (<FH2>) {
    if ( ( $gi, $ti ) = /gi(\d+)_ti(\d+)/ ) { $seq2H{$ti} = $gi; }
}
close FH2;
for $ti1 ( keys %seq1H ) {
    if ( !( exists $seq2H{$ti1} ) ) { print "gi$seq1H{$ti1}\n" }
}
