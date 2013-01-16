#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger ':levels';

# instantiate config object
my $conf = Bio::Phylo::PhyLoTA::Config->new;

# process command line arguments
my $gaps = 5;
my $incr = 1.2;
my $verbosity = WARN;
my $locus = 'rbcL';
my $alignments = $conf->WORK_DIR . '/alignments.txt';
my $outfile = 'outfile.fa';
GetOptions(
    'gaps=i'       => \$gaps,
    'incr=f'       => \$incr,
    'verbose+'     => \$verbosity,
    'locus=s'      => \$locus,
    'alignments=s' => \$alignments,
    'outfile=s'    => \$outfile,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
    '-class' => 'main',
    '-level' => $verbosity,
);

# read alignments file
my @alignments;
{
    open my $fh, '<', $alignments or die $!;
    my @all = <$fh>;
    close $fh;
    chomp( @all );
    @alignments = grep { /\/?\d+\.$locus\.fa/ } @all;
}

# the initial seed against which all others are aligned
my $seed = shift @alignments;
ALN: for my $aln ( @alignments ) {
    my $muscle = $conf->MUSCLE_BIN;
    
    # compute length and gaps for both input files
    my ($l1,$g1) = length_and_gaps( simple_fasta( read_string( $seed ) ) );
    my ($l2,$g2) = length_and_gaps( simple_fasta( read_string( $aln ) ) );
    
    # maybe skip?
    if ( $g1 > $gaps ) {
        $log->error("seed file $seed is too gappy already, can't continue");
        exit(1);
    }
    elsif ( $g2 > $gaps ) {
        $log->warn("alignment $aln is too gappy already, skipping");
        next ALN;
    }
    
    # do the alignment
    my $profile = `$muscle -quiet -profile -in1 $seed -in2 $aln`;
    
    # now assess the result
    my ( $l3,$g3 ) = length_and_gaps( simple_fasta( $profile ) );
    my @lengths = sort { $a <=> $b } $l1, $l2;
    if ( $g3 > $gaps ) {
        $log->warn("result of $seed and $aln became too gappy, skipping");
        next ALN;
    }
    elsif ( ( $l3 / $lengths[1] ) > $incr ) {
        $log->warn("length of $seed and $aln increased more than $incr, skipping");
        next ALN;
    }
    else {
        write_string( $profile, $outfile );
        $seed = $outfile;
    }
}

sub length_and_gaps {
    my %fasta = @_;
    my ($length) = map { length($_) } values %fasta;
    my ($gaps) = sort { scalar(@$b) <=> scalar(@$a) } map { [ split /-+/, $_ ] } values %fasta;
    return $length, $gaps;
}

sub read_string {
    my $file = shift;
    open my $fh, '<', $file or die $!;
    return do { local $/; <$fh> };
}

sub write_string {
    my ( $string, $file ) = @_;
    open my $fh, '>', $file or die $!;
    print $fh $string;
    close $fh;
}

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
                $log->warn("already seen definition line $current");
                $fasta{$current} = '';
            }            
        }
        else {
            $fasta{$current} .= $line;
        }
    }
    return %fasta;
} 