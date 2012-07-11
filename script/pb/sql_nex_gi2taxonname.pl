#!/usr/bin/perl
# Format requirements: NOT interleaved; no whitespace in names; semicolon after matrix has to be on separate lines;
# no comments between 'matrix' and first line of matrix; no whitespace between rows of matrix...
use DBI;
use pb;
$configFile   = "pb.conf.ceiba";                     # HACK, fix this hardcode
%pbH          = %{ pb::parseConfig($configFile) };
$release      = pb::currentGBRelease();
$database     = $release;
$clusterTable = "clusters_$release";
$seqTable     = "seqs";
$nodeTable    = "nodes_$release";
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );

while (<>) {
    if (/matrix/i) { $matrixFlag = 1; next; }
    if ($matrixFlag) {
        if (/;/) { $matrixFlag = 0; last; }
        ++$countMatrixLines;
        if (/(\'.*?\')/
          )    # non greedy match to see if there is a label in single quotes
        {
            $label = $1
              ; # if so, remove qoutes, hyphens, and replace whitespace with underscores (hack--not fully compliant with nexus conventions)
            $seq = $'; # this is the special variable for the rest of the string
            $label =~ s/'//g;
            $label =~ s/\-/\_/g;
            $label =~ s/\s/\_/g;
        }
        else { ( $label, $seq ) = split; }
        if ( ($gi) = ( $label =~ /gi(\d+)/ ) ) {
            ++$countHasGI;
            $newLabel = lookup($gi);

            #print "$newLabel\t$seq\n";
            #			print "$label  => $newLabel\n";
            push @newLabelsWithGis, $newLabel;
            $seqH{$newLabel} = $seq;
        }
        else {
            ++$countHasNoGI;

            #			print "$label  => .........\n";
            if ( $label =~ /ti\d+/ ) { push @labelsWithoutGiWithTi, $label; }
            else                     { push @labelsWithoutGiWithoutTi, $label; }
            $seqH{$label} = $seq;
        }
    }
    else { print; }    # for anything not in the matrix just print as is
}
print "matrix\n";
print "[Taxa with gis:", scalar @newLabelsWithGis, "]\n";
for $label (@newLabelsWithGis) { print "$label\t$seqH{$label}\n" }
print "[Taxa with no gis, but tis:", scalar @labelsWithoutGiWithTi, "]\n";
for $label (@labelsWithoutGiWithTi) { print "$label\t$seqH{$label}\n" }
print "[Taxa with no gis, no tis:", scalar @labelsWithoutGiWithoutTi, "]\n";
for $label (@labelsWithoutGiWithoutTi) { print "$label\t$seqH{$label}\n" }
print "\n;\nEND;\n";

#print "Has GIs: $countHasGI\n";
#print "Has no GIs: $countHasNoGI\n";
sub lookup

# lookup based on gi; check if it is a feature gi or a nuc gi. If both, DIE. Printout label using ONLY nuc gi (for features,
# use the corresponding nuc GI)
{
    my ($gi) = @_;
    $sqls =
"select gi,gi_feat,$nodeTable.ti,taxon_name from $nodeTable,features where $nodeTable.ti=features.ti and gi_feat=$gi";
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    my ( $gi_s, $gi_feat, $ti1, $name1 ) = $shs->fetchrow_array;
    $sqls =
"select gi, $nodeTable.ti,taxon_name from $nodeTable,seqs where $nodeTable.ti=seqs.ti and gi=$gi";
    $shs = $dbh->prepare($sqls);
    $shs->execute;
    my ( $gi_seq, $ti2, $name2 ) = $shs->fetchrow_array;
    $shs->finish;

    if ( defined $gi_feat && defined $gi_seq ) {
        die "Conflict between seq and feature gis (gi:$gi) in lookup\n";
    }
    if (   !( defined $gi_seq )
        && !( defined $gi_s )
      )    # last ditch...add one to accession number version and try again
    {
        return "gi$gi\_GI_NOT_FOUND";
    }
    if ( defined $gi_feat ) {
        ++$countUsingFeatureGI;
        $name1 =~ s/\'//g;     # hack to fix single quotes in cur db
        $name1 =~ s/\-/\_/g;
        $name1 =~ s/\s/\_/g;
        $formatted_label = "$name1\_gi$gi_s\_ti$ti1\t";
    }
    if ( defined $gi_seq ) {
        ++$countUsingSeqGI;
        $name2 =~ s/\'//g;     # hack to fix single quotes in cur db
        $name2 =~ s/\-/\_/g;
        $name2 =~ s/\s/\_/g;
        $formatted_label = "$name2\_gi$gi_seq\_ti$ti2\t";
    }

    #print "$gi...$gi_feat :$ti1 ... $ti2 :  $name1 ..$name2\n";
    return $formatted_label;
}
