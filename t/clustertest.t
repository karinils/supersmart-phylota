use Bio::Phylo::PhyLoTA::DAO;
use Test::More 'no_plan';

# connect to the database
my $schema = Bio::Phylo::PhyLoTA::DAO->new;

# some example GIs:
# matK: 6174789
# ITS1: 18028304
# CO1: 305690971
# rbcL: 149389752
my $seq = $schema->resultset('Seq')->find(326632174);

# this is not always going to hold, only for cytochrome B
ok($seq->length == 1140);

# search for all ci/gi intersections that contain focal GI and that are subtrees
my $cigis = $schema->resultset('CiGi')->search({ gi => $seq->gi, cl_type => "subtree" });

# some temporary variables to keep track of cluster size and root taxon 
my ( $clustersize, $biggestcluster, $taxonid ) = ( 0 );

# iterate over all intersections
while( my $c = $cigis->next ) {
    
    # print cluster identifier, root taxon identifier
    print $c->clustid," ",$c->ti,"\n";

    # fetch the actual cluster objects
    my $clusters=$schema->resultset('Cluster')->search({ ci => $c->clustid, ti_root => $c->ti});
    
    # iterate over clusters
    while (my $cluster=$clusters->next){
        
        # looking for the largest cluster, i.e. keeping a running tally 
        if ($cluster->n_ti > $clustersize ){
            $clustersize = $cluster->n_ti;
            $biggestcluster = $cluster->ci;
            $taxonid = $cluster->ti_root;
        }
        print "CLUSTER: ",$cluster->pi," ",$cluster->n_ti,"\n";
    }
}

# now get the biggest cluster
print "biggestcluster: ",$biggestcluster," ",$taxonid->ti,"\n";
my $gis=$schema->resultset('CiGi')->search({ cl_type => 'subtree', ti => $taxonid->ti, clustid => $biggestcluster});

# ... and print to FASTA
#while(my $gi=$gis->next){
#    print ">",$gi->gi, "\n";
#    my $seq=$schema->resultset('Seq')->find($gi->gi);
#    print $seq->seq,"\n";
#}