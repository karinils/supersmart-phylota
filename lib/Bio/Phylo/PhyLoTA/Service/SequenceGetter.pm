# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::SequenceGetter; # maybe this should be SequenceService
use strict;
use warnings;
use Moose;
use Bio::SeqIO;

extends 'Bio::Phylo::PhyLoTA::Service';

sub store_genbank_sequences {
    my ( $self, $file ) = @_;
    
    # also allow gzipped files, pipe from gunzip -c
    my $command = ( $file =~ /\.gz$/ ) ? "gunzip -c $file |" : "< $file";
    
    # instantiate bioperl sequence reader
    my $reader  = Bio::SeqIO->new(
        '-format' => 'genbank',
        '-file'   => $command,
    );
    
    # iterate over sequences in file
    while( my $seq = $reader->next_seq ) {
        $self->store_sequence($seq);
    }
}

# stores a bioperl sequence object, if optional second argument is true we
# won't store the raw sequence string (because it would be too long). returns
# the newly created dao Seq object
sub store_sequence {
    my ( $self, $bioperl_seq, $no_raw ) = @_;
    my @dates = $bioperl_seq->get_dates();
    return $self->schema->resultset('Seq')->create( {
        'acc_date' => _formatDate( $dates[-1] ),
        'gbrel'    => $self->config->currentGBRelease,
        'seq'      => $no_raw ? undef : $bioperl_seq->seq,        
        'acc'      => $bioperl_seq->accession_number,
        'acc_vers' => $bioperl_seq->seq_version,
        'def'      => $bioperl_seq->desc,
        'division' => $bioperl_seq->division,
        'gi'       => $bioperl_seq->primary_id,
        'length'   => $bioperl_seq->length,
        'ti'       => $bioperl_seq->species->ncbi_taxid
    });
}

# then populate the CDS and RNA features, taking care with remotely accessioned features.
# NB! Bioperl feature->spliced_seq will just return a guess at the length of the sequence, padded with 'N's
# when the acc number is remote. This is often a bad guess because it is based on the presumption that the
# ENTIRE feature is remote, when often just a piece of the feature is remote. Go ahead, look at the code...
#    if( !defined $called_seq ) {
#	$seqstr .= 'N' x $self->length;  ...here the length is for the feature's location, not the features sublocation
#	next; ...so for something like join(BC123.1:1-100, 12-200,10000-10100) it might be 10100 minus 12.
# DO NOT USE feat->length for split sequences at all! unless you want the length of the whole region from min to max
sub store_feature {
    my ( $self, $daoseq, $feat, $no_raw ) = @_;

    # parameters for the Feature create method below
    my %params = (
        'primary_tag'   => $feat->primary_tag,
		'gi'            => $daoseq->gi,
		'ti'            => $daoseq->ti,
        'range'         => $feat->location->to_FTstring(),
        
        # these we will populate out of the tags we read below
        'gene'          => undef, # gene symbol
        'transl_table'  => undef, # translation table
        'codon_start'   => undef, # reading frame
        'product'       => undef, # gene product
        'gi_feat'       => undef, # db_xref        
        'acc'           => undef, # accession number, the part before the version
        'acc_vers'      => undef, # accession number version, i.e. a number after the dot
        'seq'           => undef, # the raw sequence, may remain undef if remote
        'length'        => undef, # length of the raw sequence
    );    
    
    # if we don't trap for remote sequences, bad things happen, see above.
    if ( ! grep { $_->is_remote } $feat->location->each_Location() && ! $no_raw ) {
        $params{'seq'} = $feat->spliced_seq()->seq();
        $params{'length'} = length $params{'seq'};
    }
    
    # every feature has a number of key value pairs associated with them
    for my $tag ( $feat->get_all_tags() ) {
        my $value = join( ' ', $feat->get_tag_values($tag) );
        $params{$tag} = $value if exists $params{$tag};
        
        # only keep the numerical part of db_xref
        if ( $tag eq 'db_xref' && $value =~ /(\d+)/ ) {
            $params{'gi_feat'} = $1;
        }
        
        # split protein_id as an accession number
        if ( $tag eq 'protein_id' && $value =~ /^([^.]+)\.(.*)$/ ) {
            ( $params{'acc'}, $params{'acc_vers'} ) = ( $1, $2 );
        }
    }
    
    # some CDS features are not taken seriously, not translated, etc., so skip
    if ( $feat->primary_tag =~ /CDS/ ) {        
        return if not defined $params{'acc'};
    }

    return $self->schema->resultset('Feature')->create( \%params );
}

sub _formatDate {
    my %monthH = (
        JAN => 1,
        FEB => 2,
        MAR => 3,
        APR => 4,
        MAY => 5,
        JUN => 6,
        JUL => 7,
        AUG => 8,
        SEP => 9,
        OCT => 10,
        NOV => 11,
        DEC => 12
    );
    my ( $day, $month, $year ) = split '\-', $_[0];
    return "$year-$monthH{$month}-$day";
}

sub get_largest_cluster_for_sequence{
    my($self,$gi)=@_;
    
    # get the logger from Service.pm, the parent class
    my $log=$self->logger;
    
    # search CiGi table for all subtree clusters that include provided gi
    my $cigis = $self->schema->resultset('CiGi')->search({ gi => $gi, cl_type => "subtree" });
    
    # clusterid for most inclusive cluster
    my $biggestcluster;
    
    # size of the most inclusive cluster
    my $clustersize=0;
    
    # root_taxon of the most inclusive cluster
    my $taxonid;
    
    # iterate over search results
    while(my $c=$cigis->next){
	$log->info($c->clustid," ",$c->ti,"\n");
	
	# search cluster table for all clusters with clustid and ti from cigi result
	my $clusters=$self->schema->resultset('Cluster')->search({ ci => $c->clustid, ti_root => $c->ti});
	
	# iterate over search results
	while (my $cluster=$clusters->next){
	    
	    # looking for most inclusive cluster with largest n_ti
	    if ($cluster->n_ti > $clustersize ){
		$clustersize=$cluster->n_ti;
		$biggestcluster=$cluster->ci;
		$taxonid=$cluster->ti_root;
	    }
	    $log->info("CLUSTER: ",$cluster->pi," ",$cluster->n_ti,"\n");
	}
    }
    $log->info("biggestcluster: ",$biggestcluster," ",$taxonid->ti,"\n");
    
    # search CiGi table for sequences with most inclusive cluster
    my $gis=$self->schema->resultset('CiGi')->search({ cl_type => 'subtree', ti => $taxonid->ti, clustid => $biggestcluster});
    
    # this will hold the resulting sequences
    my @sequences;
    
    # iterate over search results
    while(my $gi=$gis->next){
	
	# look up sequence by it's unique id
	my $seq=$self->schema->resultset('Seq')->find($gi->gi);
	
	# add sequence to results
	push @sequences, $seq;
    }
    
    # return results
    return @sequences;
}

sub compute_median_seq_length {
    my ($self,@seq) = @_;
    
    # count number of occurrences of each sequence length
    my %occurrences;
    for my $seq (@seq) {
	$occurrences{ $seq->length }++;
    }
    
    # similar to $clustersize (line 141) and $biggestcluster (line 138)
    my ($n_occurrences,$most_seen_length) = (0,0);
    
    # iterate over all lengths
    for my $length ( keys %occurrences ) {
	
	# similar to line 156
	if ( $occurrences{$length} > $n_occurrences ) {
	    $most_seen_length = $length;
	    $n_occurrences = $occurrences{$length};
	}
    }
    
    # e.g. for Cytochrome B this should return 1140
    return $most_seen_length;
}

1;

=head1 NAME

Bio::Phylo::PhyLoTA::Service::SequenceGetter - Sequence Getter

=head1 DESCRIPTION

Gets sequences for all species from Genbank (www.ncbi.nlm.nih.gov).

=cut
