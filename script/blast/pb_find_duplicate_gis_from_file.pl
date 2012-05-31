#!/usr/bin/perl -w
$count = 0;
while (<>) {
    ( $ti, $clustid, $cl_type, $gi ) = split;
    $key = "$ti\_$clustid\_$cl_type\_$gi";
    if ( $seen{$key} ) {
        print "$key is a duplicate\n";
        ++$count;
        $tiH{$ti} = 1;
    }
    else {
        $seen{$key} = 1;
    }
}
$nti = keys %tiH;
print "There were $count duplicate gis among $nti distinct tis\n";
