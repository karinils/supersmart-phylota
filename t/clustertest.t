use Bio::Phylo::PhyLoTA::DAO;
use Test::More 'no_plan';

# connect to the database
my $schema = Bio::Phylo::PhyLoTA::DAO->new;
# GI:326632174
my $seq = $schema->resultset('Seq')->find(326632174);
#print $seq->seq;
ok($seq->length == 1140);

#
my $cigis = $schema->resultset('CiGi')->search({ gi => $seq->gi, cl_type => "subtree" });
my $biggestcluster;
my $clustersize=0;
my $taxonid;
while(my $c=$cigis->next){
    print $c->clustid," ",$c->ti,"\n";
    my $clusters=$schema->resultset('Cluster')->search({ ci => $c->clustid, ti_root => $c->ti});
    while (my $cluster=$clusters->next){
        if ($cluster->n_ti > $clustersize ){
            $clustersize=$cluster->n_ti;
            $biggestcluster=$cluster->ci;
            $taxonid=$cluster->ti_root;
        }
        print "CLUSTER: ",$cluster->pi," ",$cluster->n_ti,"\n";
    }
}
print "biggestcluster: ",$biggestcluster," ",$taxonid->ti,"\n";

my $gis=$schema->resultset('CiGi')->search({ cl_type => 'subtree', ti => $taxonid->ti, clustid => $biggestcluster});
while(my $gi=$gis->next){
    print ">",$gi->gi, "\n";
    my $seq=$schema->resultset('Seq')->find($gi->gi);
    print $seq->seq,"\n";
}