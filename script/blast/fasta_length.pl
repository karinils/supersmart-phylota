#!/opt/rocks/bin/perl
use Bio::SeqIO;
while ( $fl = shift @ARGV ) {
    if ( $fl eq '-f' )         { $faFile    = shift @ARGV; }
    if ( $fl eq '-outfa' )     { $outfa     = shift @ARGV; }
    if ( $fl eq '-outlength' ) { $outlength = shift @ARGV; }
}
open FH1, ">$outlength";
$seqio_obj = Bio::SeqIO->new( -file => $faFile,   -format => "fasta" );
$out       = Bio::SeqIO->new( -file => ">$outfa", -format => 'fasta' );
while ( $seq_obj = $seqio_obj->next_seq ) {
    $def = $seq_obj->display_id . " "
      . $seq_obj->desc;    # this is how Bioperl makes a definition line!
    $seq = $seq_obj->seq;
    if ( ($gi) = ( $def =~ /gi(\d+)/ ) ) {
        print FH1 "$gi\t", length($seq) . "\n";
        $seq_obj->display_id($gi);
        $seq_obj->desc("");
        $out->write_seq($seq_obj);
    }
}
