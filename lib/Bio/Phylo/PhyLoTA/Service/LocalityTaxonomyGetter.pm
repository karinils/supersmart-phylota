package Bio::Phylo::PhyLoTA::Service::LocalityTaxonomyGetter;
use strict;
use warnings;
use IO::File;
use Data::Dumper;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::PhyLoTA::DAO;
use Bio::Phylo::PhyLoTA::Service::GbifReader;

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new;

# instantiate schema
my $schema = Bio::Phylo::PhyLoTA::DAO->new;

sub store_gbif_ids {
    my ( $self, $file ) = @_;
    
    # instantiate reader 
    my $r = Bio::Phylo::PhyLoTA::Service::GbifReader->new( 'file' => $file );    
    
    # iterate over GBIF species, try to match with NCBI
    while ( my $species = $r->next_species ) {
        my $gbif_id = $species->id;
        
        # search on name initially
        if ( my $gbif_name = $species->binomial ) {
            my @nodes = $schema->resultset('Node')->search( { 'taxon_name' => $gbif_name } )->all;
            
            # create a lookup table for names in the GBIF lineage,
            # with their 'depth' (node distance from tip)
            my $depth = 0;
            my %classification = map { $_ => $depth++ } $species->classification;
            
            # iterate over NCBI nodes that match the binomial
            MATCH: for my $node ( @nodes ) {
                my $ti = $node->ti;
                
                # traverse classification for focal NCBI node
                my ( $seen, %lookup ) = ( 0 );
                NODE: while( $node ) {
                    last NODE if $seen == $depth;
                    my $name = $node->taxon_name;
                    
                    # these don't all exist because NCBI has more
                    # levels than GBIF
                    if ( exists $classification{$name} ) {
                        
                        # if $seen is higher, it means levels were
                        # in different order
                        if ( $seen <= $classification{$name} ) {
                            $lookup{$name} = $seen++;
                        }
                        else {
                            $log->warn("apparent mismatch in higher ranks");
                            next MATCH;
                        }
                    }
                    
                    # go to parent
                    $node = $schema->resultset('Node')->find($node->ti_anc);
                }
                
                # if we reach this point, we've found a valid match
                $log->warn("GBIF:$gbif_id <=> NCBI:$ti");
                $log->debug("GBIF:".Dumper(\%classification));
                $log->debug("NCBI:".Dumper(\%lookup));
            }
        }
        else {
            $log->warn("no binomial for GBIF record " . $species->id());
        }
    }
}


1;