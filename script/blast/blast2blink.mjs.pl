#!/usr/bin/perl -w
# Modified MJS Oct 2006 to allow overwriting of outfile
# Modified MJS July 2008 to drop the 'gi' prefix on gi numbers
# Also, it seems as if there is no default for mode option; it must be supplied
#  script to convert blastall output to blink input.
#
#  input:   file containing blast output in tabular format (option "-m 8" for NCBI blast)
#		where each line corresponds to a hit
#	    file containing table of local seq ids
#
#  output:  file containing paired hits without remaining information, translated into
#		special format of giXXX..
#
#  30 jan 05:  accepts only those comparisons with sufficent length overlap in both
#	directions.
#  12 mar 05:  added a mode that disables the length requirement and outputs six columns:
#	gi1 gi2 startPosition1 stopPosition1 start2 stop2
#  23 apr 05:  added flexibility to input format -- lines 74 and 75 now require either gi|xxx or gixxx
#  2 jul 05:  added function to skip the edge if one strand is reversed relative to the other (for either mode)
#  14 jul 05:  added mode to allow proportional overlap requirement for only one seq
#  14 jul 05:  added function to add the lengths of the hits when asking if proportional overlap is sufficent (modes 1 and 2).
#  15 jul 05:  added option to take a file containing a list of gis and only report edges that involve those gis.
#  17 jul 05:  added function to calculate phi, where phi is a measurement (0 to 1) of the amount of unalignable bases for each side.
#		decisions can be made on the min phi and max phi.
#		note:  absolute values are considered for acceptability of edge -- could be changed in future.
#  18 jul 05: changed definition of phi -- length of sequence involved in all hits divided by total spanned by both "strands".
#
$Usage = "
Usage:
		./blast2blink.pl 
			-i infile  
				in 11-column format, acheived using blast's -m 8 option.
				NOTE: expects gi|xxx or gixxx in the blast output where xxx is the gi number
				  in the first field, and the beginning and end positions in the 7th, 8th, 9th, 10th fields.
			-o outfile
				two-column file of gis that were accepted by all criteria, ready for blink.
			-t table file [optional]
				FOR EST PROJECT:
					table file is two column: uniqID length


				IGNORE:
				fields must be delimited by bars |.  
				first field must contain the gi in gixxx format.
				third field must contain the length of the sequence.
				if values are given for sigma or phi, this file is required.
			-g filename [optional]
				file that contains a list of gis.  
				if specified, the output will contain only those edges involving gis on this list.
				gis must be gixxx or gi|xxxx and can be in any column but only one per line. 
			-p phi threshhold, 0 to 1 [optional]
				minimum phi threshhold.  
				phi is the number of bases spanned by all hits between two sequences, 
				  scaled to the total number of bases spanned by both sequences,
				  including unaligned \"sticky ends\".
				default = 0.
			-s sigma treshhold, 0 to 1 [optional]
				minimum sigma allowed. 
				sigma is, for each sequence in a pair, the total number of bases involved 
				  in all hits, scaled by the length of that sequence.
				default = 0.
			-m mode  [optional]
				2 requires that sigma values for each strand are above the minimum.
				1 requires that the sigma value for at least one strand is above the minimum.
				if a value is given for sigma, mode 2 is the default.

	Calculation of phi and sigma:
					a 	  b1   	c1   b2   c2  ... bn     cn   d		    letters refer to positions in unaligned seq.
					-----------------------------------------------
						  |||||||    |||\\\\       \\\||||
					     ----------------------------------------------------
					     w	  x1	y1   x2	    y2	    xn   yn		z


				phi = 	max ((cn-b1),(yn-x1)) /
					( max((b1-a),(x1-w)) + max ((cn-b1),(yn-x1)) + max((z-yn),(d-cn)) )

				sigma1 = (sum(ci-bi+1))/d), i = 1 to n 	
				sigma2 = (sum(yi-xi+1))/z), i = 1 to n	

			NOTE: this description is not quite correct:  the sums are actually set unions, because hits can overlap.  

	examples:

		./blast2blink.pl -i paps.blast.out -o paps.hitsp90s90 -t paps.table -s 0.9 -p 0.9
			makes a hitlist where each edge consists of sequences that are similar enough to hit with at least 90% 
			  their bases and similar enough in length that the hitting region is at least 90% of the total 
			  region spanned.
		
		./blast2blink.pl -i paps.blast.out -o paps.sampleHitsp50s20 -t paps.table -s 0.2 -p 0.5 -g paps.sampleGis
			makes a hitlist that involve only the gis in the sample file, for which 20% or more of each seq hits
			  to the other, and where the hitting region spans at least 50% of the total region spanned. 

		./blast2blink.pl -i paps.blast.out -o paps.hitsp0s90 -m 1 -s 0.9
			makes a hitlist where at least 90% of at least one of the sequences hits to the other, and no restrictions
			  are placed on where those hits are in the total region spanned.

";

# command line input ----------------------------------
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-i/ ) { $infile    = $par; }
    if ( $fl =~ /-o/ ) { $outfile   = $par; }
    if ( $fl =~ /-t/ ) { $tablefile = $par; }
    if ( $fl =~ /-g/ ) { $gifile    = $par; }
    if ( $fl =~ /-p/ ) { $phiT      = $par; }
    if ( $fl =~ /-s/ ) { $sigmaT    = $par; }
    if ( $fl =~ /-m/ ) { $mode      = $par; }
}
die("$Usage") if ( !( $infile && $outfile ) );

# ...MJS
if (   -e $infile
    && -z $infile
  )  # input exists but has size zero, so there were probably no blast hits all;
{
    open FH2, ">$outfile";
    close FH2;    # so write the output file with zero size;
    exit(0);
}
die("Missing infile $infile.\n") if ( !-e $infile );

#die ("Output file already exists.\n") if (-e $outfile);
die("Missing table file.\n") if ( $tablefile && ( !-e $tablefile ) );
die("Missing gi file.\n")    if ( $gifile    && ( !-e $gifile ) );
if ( $sigmaT || $phiT ) {
    die("Must supply table if using sigma and phi\n$Usage") if ( !$tablefile );
}
if ( !$sigmaT ) { $sigmaT = 0; }
if ( !$phiT )   { $phiT   = 0; }
$v  = 0;
$v1 = 0;

# make length hash if mode 1 or 2  ---------------------
# ALTERED FOR EST PROJECT
if ($mode) {
    open FH3, "<$tablefile";
    while (<FH3>) {
        next if (/^\s*$/);
        @fields = split;
        if ( $fields[0] =~ /(\w+)/ ) {
            $gi = $1;
            if ( $fields[1] =~ /(\d+)/ ) { $giLengthH{$gi} = $1; }
            else {
                die(
"Problem with format of table file (column 2 is not a number).\n"
                );
            }
        }
        else {
            die(
"Problem with format of table file (column 0 does not contain seqid).\n"
            );
        }
    }
    close FH3;
}

# read gi file if necessary ----------------------------
if ($gifile) {
    $targs = 1;
    open FHg, "<$gifile";
    while (<FHg>) {
        ($gi) = /gi\|?(\d+)/;
        if ( !exists $trgGi{$gi} ) { $trgGi{$gi} = 1; }
    }
    close FHg;
}
else { $targs = 0; }

# parse blast output -----------------------------------
open FH1, "<$infile"
  or die "Could not open infile (name=$infile) for reading in blast2blink\n";
open FH2, ">$outfile"
  or die "Could not open outfile (name=$outfile) for writing in blast2blink\n";
if ( !$mode ) {
    while (<FH1>) {
        @d = split;
        ( $def1, $def2, $b1, $e1, $b2, $e2 ) =
          ( $d[0], $d[1], $d[6], $d[7], $d[8], $d[9] );
        if ( ( $b1 > $e1 ) || ( $b2 > $e2 ) ) {
            print "Reversal in hit $def1 $def2\n";
        }
        $gi1 = $def1;
        $gi2 = $def2;
        if ($targs) {
            next if ( ( !exists $trgGi{$gi1} ) || ( !exists $trgGi{$gi2} ) );
        }
        print FH2 "$gi1\t$gi2\n";
    }
}
else {
    $oldGi1 = "";
    $oldGi2 = "";
    while (<FH1>) {
        @d = split;
        if ($v1) { print "Considering line:\n$_"; }
        ( $def1, $def2, $b1, $e1, $b2, $e2 ) =
          ( $d[0], $d[1], $d[6], $d[7], $d[8], $d[9] );
        if ( ( $b1 > $e1 ) || ( $b2 > $e2 ) ) {
            print "Reversal in hit $def1 $def2\n";
        }
        $newGi1 = $def1;
        $newGi2 = $def2;
        if (   ( $newGi1 eq $oldGi1 )
            && ( $newGi2 eq $oldGi2 )
          ) # assumes that all hits between two gis are sequential in blast ouput
        {   # HACK -- this assumption must be checked!!
                # add to existing record if same as before ------
            push @{$r1ref}, [ $b1, $e1 ];
            push @{$r2ref}, [ $b2, $e2 ];
        }
        else {

            # process old record, if exists -----------------
            if ( $oldGi1 =~ /\w/ ) {
                if ($v1) {
                    print "\ncalculating stats for pair $oldGi1 and $oldGi2:\n";
                }
                ( $sigma1, $sigma2, $phi ) =
                  processRecord( $oldGi1, $oldGi2, $r1ref, $r2ref );
                $accept = acceptRecord( $sigma1, $sigma2, $phi );
                if ($accept) { print FH2 "$oldGi1\t$oldGi2\n"; }
                if ($v) {
                    print
"the edge has acceptance:$accept\tbecause:  $sigma1, $sigma2, $phi\n";
                }
                if ($v) {
                    print "Continue?\n";
                    $answer = (<STDIN>);
                    die if ( $answer =~ /n/i );
                }
                $oldGi1 = "";
                $oldGi2 = "";
            }

            # start new record -------------------------------
            if (
                (
                       $targs
                    && ( exists $trgGi{$newGi1} )
                    && ( exists $trgGi{$newGi2} )
                )
                || ( !$targs )
              )
            {
                $r1ref = [ [ $b1, $e1 ] ];
                $r2ref = [ [ $b2, $e2 ] ];
                $oldGi1 = $newGi1;
                $oldGi2 = $newGi2;
            }
        }    # end if new edge
    }    # end while reading lines, process last set ------
    if ( ( $targs && ( exists $trgGi{$newGi1} ) && ( exists $trgGi{$newGi2} ) )
        || ( !$targs ) )
    {
        if ($v1) {
            print "calculating stats for last pair, $oldGi1 and $oldGi2:\n";
        }
        ( $sigma1, $sigma2, $phi ) =
          processRecord( $oldGi1, $oldGi2, $r1ref, $r2ref );
        $accept = acceptRecord( $sigma1, $sigma2, $phi );
        if ($accept) { print FH2 "$oldGi1\t$oldGi2\n"; }
    }
}    # end if mode 1 or 2
close FH1;
close FH2;

# subroutines --------------------------------------------------------------------------
#  findPhi, findSumAndRange, acceptRecord, processRecord
# sub processRecord ----------------------------------------------
#	takes array
#		($gi1, $gi2, $r1ref, $r2ref) where rXref points
#		  to an array of start/stop pairs for the gi.
#	must have access to giLengthH
#	calls sub findSumAndRange and findPhi
#	returns array
#		($sigma1, $sigma2, $phi)
sub processRecord {
    my ( $gi1, $gi2, $r1ref, $r2ref ) = @_;
    my $length1 = $giLengthH{$gi1};
    my $length2 = $giLengthH{$gi2};
    my ( $sum1, $first1, $last1 ) = findSumAndRange($r1ref);
    my ( $sum2, $first2, $last2 ) = findSumAndRange($r2ref);
    my $sigma1 = $sum1 / $length1;
    my $sigma2 = $sum2 / $length2;
    if ($v1) {
        print
"sigma1: $sigma1 = $sum1/$length1\nsigma2: $sigma2 = $sum2/$length2\n";
    }
    my $phi = findPhi( $length1, $first1, $last1, $length2, $first2, $last2 );
    return ( $sigma1, $sigma2, $phi );
}

# subroutine findPhi ---------------------------------------------
#	takes array of edge data:
#		($length2, $first1, $last1, $length2, $first2, $last2)
#	returns phi
sub findPhi {
    my ( $length1, $first1, $last1, $length2, $first2, $last2 ) = @_;
    my $l1     = $first1 - 1;
    my $l2     = $first2 - 1;
    my $r1     = $length1 - $last1;
    my $r2     = $length2 - $last2;
    my $h1     = $last1 - $first1 + 1;
    my $h2     = $last2 - $first2 + 1;
    my @lefts  = sort { $a <=> $b } ( $l1, $l2 );
    my @hits   = sort { $a <=> $b } ( $h1, $h2 );
    my @rights = sort { $a <=> $b } ( $r1, $r2 );
    if ($v1) { print "region array:  ($l1, $l2, $h1, $h2, $r1, $r2)\n"; }
    if ($v1) { print "sorted info: @lefts, @hits, @rights\n"; }
    my $phi = ( $hits[1] ) / ( $lefts[1] + $hits[1] + $rights[1] );

    if ($v1) {
        print "phi: $phi = ($hits[1]) / ($lefts[1] + $hits[1] + $rights[1]) \n";
    }
    return $phi;
}

# subroutine findSumAndRange -------------------------------------
#	takes array ref that points to array of arrays
#		($r1ref)
#	returns array: sum of hits, start of first hit, end of last hit
#		($sum, $first, $last)
sub findSumAndRange {
    my ($aref) = @_;
    my ( $sum, $first, $last, $min, $max ) = ( 0, 0, 0, 0, 0 );
    my $bb    = 0;
    my $eb    = 0;
    my @refsA = @{$aref};
    my $sRefs = ();
    my $n     = scalar @refsA;
    if ( $n == 1 ) {
        $sum = ( $refsA[0][1] - $refsA[0][0] + 1 );
        ( $first, $last ) = ( $refsA[0][0], $refsA[0][1] );
    }
    else {
        @sRefs = sort { ${$a}[0] <=> ${$b}[0] } @refsA;
        ( $min, $max ) = @{ $sRefs[0] };
        $first = $min;
        for $i ( 1 .. ( $n - 1 ) ) {
            if ( $sRefs[$i][0] > $max )    # ranges do not intersect
            {
                $sub = ( $max - $min + 1 );
                $sum += $sub;
                ( $min, $max ) = @{ $sRefs[$i] };
            }
            else {
                if ( $sRefs[$i][1] > $max )    # range can be expanded
                {
                    $max = $sRefs[$i][1];
                }
            }
        }
        $last = $max;
        $sub  = ( $max - $min + 1 );
        $sum += $sub;
    }
    return ( $sum, $first, $last );
}

# sub acceptRecord -----------------------------------------------
#	takes array
#		($sigma1, $sigma2, $phi)
#	must have access to all cutoffs and mode value.
#	returns 1 if the record passes sigma and phi criteria
#		otherwise returns 0.
sub acceptRecord {
    my ( $sigma1, $sigma2, $phi ) = @_;
    my ( $acceptableSum, $acceptablePhi, $pass ) = ( 0, 0, 0 );
    if ( $mode == 2 ) {
        if ( ( $sigma1 >= $sigmaT ) && ( $sigma2 >= $sigmaT ) ) {
            $acceptableSum = 1;
        }
        else { $acceptableSum = 0; }
    }
    elsif ( $mode == 1 ) {
        if ( ( $sigma1 >= $sigmaT ) || ( $sigma2 >= $sigmaT ) ) {
            $acceptableSum = 1;
        }
        else { $acceptableSum = 0; }
    }
    if   ( $phi >= $phiT ) { $acceptablePhi = 1; }
    else                   { $acceptablePhi = 0; }
    if   ( $acceptableSum && $acceptablePhi ) { $pass = 1; }
    else                                      { $pass = 0; }
    return $pass;
}
