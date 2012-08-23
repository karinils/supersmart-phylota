# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::SequenceGetter; # maybe this should be SequenceService
use strict;
use warnings;
use Moose;
use Bio::SeqIO;
use Bio::Tools::Run::Alignment::Muscle;
use Bio::Phylo::Factory;

extends 'Bio::Phylo::PhyLoTA::Service';

my $fac=Bio::Phylo::Factory->new;

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

# this fetches the largest containing cluster for the seed sequence. This is a higher
# taxon, such as an order, for example.
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
    return $self->get_sequences_for_cluster_object({ cl_type => 'subtree', ti => $taxonid->ti, clustid => $biggestcluster});
}

# this method fetches the smallest containing cluster for the seed sequence, typically
# these are the results of all-vs-all blasting within a fairly low level taxon such as
# a family or a large genus (according to the NCBI taxonomy).
sub get_smallest_cluster_for_sequence{
    my($self,$gi)=@_;
    
    # get the logger from Service.pm, the parent class
    my $log=$self->logger;
    
    # search CiGi table for all subtree clusters that include provided gi
    my $cigis = $self->schema->resultset('CiGi')->search({ gi => $gi, cl_type => "subtree" });
    
    # clusterid for least inclusive cluster
    my $smallestcluster;
    
    # size of the least inclusive cluster
    my $clustersize=undef;
    
    # root_taxon of the least inclusive cluster
    my $taxonid;
    
    # iterate over search results
    while(my $c=$cigis->next){
	$log->info($c->clustid," ",$c->ti,"\n");
	
	# search cluster table for all clusters with clustid and ti from cigi result
	my $clusters=$self->schema->resultset('Cluster')->search({ ci => $c->clustid, ti_root => $c->ti});
	
	# iterate over search results
	CLUSTER: while (my $cluster=$clusters->next){
	    
	    if (not defined $clustersize){
		$clustersize=$cluster->n_ti;
		$smallestcluster=$cluster->ci;
		$taxonid=$cluster->ti_root;
		next CLUSTER;
	    }
	    
	    # looking for least inclusive cluster with largest n_ti
	    if ($cluster->n_ti < $clustersize ){
		$clustersize=$cluster->n_ti;
		$smallestcluster=$cluster->ci;
		$taxonid=$cluster->ti_root;
	    }
	    $log->info("CLUSTER: ",$cluster->pi," ",$cluster->n_ti,"\n");
	}
    }
    $log->info("smallestcluster: ",$smallestcluster," ",$taxonid->ti,"\n");
    
    # search CiGi table for sequences with most inclusive cluster
    return $self->get_sequences_for_cluster_object({ cl_type => 'subtree', ti => $taxonid->ti, clustid => $smallestcluster});
}

sub get_sequences_for_cluster_object {
    # $cluster_object is a hash reference with the following keys:
    # - cl_type => either node or subtree
    # - ti      => the taxon id for the root taxon
    # - clustid => the cluster id, which is NOT a primary key
    my ($self,$cluster_object) = @_;
    
    # search CiGi table to fetch all GIs within this cluster
    my $gis = $self->schema->resultset('CiGi')->search($cluster_object);

    # this will hold the resulting sequences
    my @sequences;
    
    # iterate over search results
    while(my $gi = $gis->next){
	
	# look up sequence by it's unique id
	my $seq = $self->schema->resultset('Seq')->find($gi->gi);
	
	# add sequence to results
	push @sequences, $seq;
    }
    
    # return results
    return @sequences;    
}

sub get_smallest_cluster_object_for_sequence{
    my($self,$gi)=@_;
    
    # get the logger from Service.pm, the parent class
    my $log=$self->logger;
    
    # search CiGi table for all subtree clusters that include provided gi
    my $cigis = $self->schema->resultset('CiGi')->search({ gi => $gi, cl_type => "subtree" });
    
    # clusterid for least inclusive cluster
    my $smallestcluster;
    
    # size of the least inclusive cluster
    my $clustersize=undef;
    
    # root_taxon of the least inclusive cluster
    my $taxonid;
    
    # iterate over search results
    while(my $c=$cigis->next){
	$log->info($c->clustid," ",$c->ti,"\n");
	
	# search cluster table for all clusters with clustid and ti from cigi result
	my $clusters=$self->schema->resultset('Cluster')->search({ ci => $c->clustid, ti_root => $c->ti});
	
	# iterate over search results
	CLUSTER: while (my $cluster = $clusters->next){
	    
	    if (not defined $clustersize){
		$clustersize = $cluster->n_ti;
		$smallestcluster = $cluster->ci;
		$taxonid = $cluster->ti_root;
		next CLUSTER;
	    }
	    
	    # looking for least inclusive cluster with largest n_ti
	    if ($cluster->n_ti < $clustersize ){
		$clustersize = $cluster->n_ti;
		$smallestcluster = $cluster->ci;
		$taxonid = $cluster->ti_root;
	    }
	    $log->info("CLUSTER: ",$cluster->pi," ",$cluster->n_ti,"\n");
	}
    }
    $log->info("smallestcluster: ",$smallestcluster," ",$taxonid->ti,"\n");
    
    # input to search CiGi table for sequences within cluster
    return { cl_type => 'subtree', ti => $taxonid->ti, clustid => $smallestcluster };
}

sub get_parent_cluster_object {
    my ($self,$cluster) = @_;
    my $ci = $cluster->{clustid} || $cluster->{ci};
    my $ti = $cluster->{ti} || $cluster->{ti_root};
    my $node = $self->schema->resultset('Node')->find($ti);
    my $parent_id = $node->ti_anc;
    return { cl_type => 'subtree', ti => $parent_id, clustid => $ci };
}

sub get_child_cluster_objects {
    my ($self,$cluster) = @_;
    my $ci = $cluster->{clustid} || $cluster->{ci};
    my $ti = $cluster->{ti} || $cluster->{ti_root};
    my $nodes = $self->schema->resultset('Node')->search({ ti_anc => $ti });
    my @result;
    while(my $node = $nodes->next) {
	push @result, { cl_type => 'subtree', ti => $node->ti, clustid => $ci };
    }
    return @result;
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

# this method filters out duplicate sequences per taxon ,and prefers to keep sequences of the median lenght accross
# the whole set, otherwise keep longer sequences, or otherwise keep shorter ones

# TODO: make it so that all else being equal we prefer the sequence with the lowest number of NNNN
sub filter_seq_set {
    my ($self,@seq) = @_;
    
    # compute accross the whole set
    my $median_length = $self->compute_median_seq_length(@seq);
    
    # this is what we return, sequence objects
    my @filtered_seqs;
    
    # multidimensional hash, top level keys are taxon ids, second level keys are raw sequences, values are sequence
    # objects
    my %sequences_for_taxon;
    
    # iterate over all sequences
    for my $seq(@seq) {
	
	# this fetches the NCBI taxon id
	my $ti = $seq->ti;
	
	# create an anonymous hash first time we see this taxon id
	if(not exists $sequences_for_taxon{$ti}){
	    $sequences_for_taxon{$ti}={};
	}
	
	# assign the sequence object to raw sequence as key, this filters out duplicate sequences
	$sequences_for_taxon{$ti}->{$seq->seq}=$seq;
    }
    
    # iterate over taxon ids
    for my $ti(keys %sequences_for_taxon){
	
	# contains raw sequence strings after filtering by length
	my @raw_seqs;
	
	# contains raw sequence strings before filtering by length
	my @taxon_seqs = keys %{ $sequences_for_taxon{$ti} };
	
	# only keep sequemces of median length
	my @median_length_seqs = grep { length($_) == $median_length } @taxon_seqs;
	
	# only keep sequences larger than median length
	my @longer_seqs = grep { length($_) > $median_length } @taxon_seqs;
	
	# tests if there were sequnces of median length
	if (@median_length_seqs){
	    push @raw_seqs,@median_length_seqs;
	}
	
	# tests if there were sequences larger than median length
	elsif (@longer_seqs){
	    push @raw_seqs,@longer_seqs;
	}
	
	# there were only shorter sequences
	else {
	    push @raw_seqs,@taxon_seqs;
	}
	
	# map raw sequences back to sequence objects
	my @seq_objects = map { $sequences_for_taxon{$ti}->{$_} } @raw_seqs;
	push @filtered_seqs,@seq_objects;
    }
    
    # return results
    return @filtered_seqs;
}

sub align_sequences{
    my ($self,@seq)=@_;
    
    # here we convert sequence objects from the database, i.e. Bio::Phylo::PhyLoTA::DAO::Result::Seq
    # objects (which are not compatible with bioperl) into Bio::Phylo::Matrices::Datum object, which
    # ARE compatible, so that we can pass those into the muscle wrapper
    my @convertedseqs;
    for my $seq(@seq){
	my $converted=$fac->create_datum(
	    -type => 'dna',
	    -name => $seq->gi,
	    -char => $seq->seq,
	);
	push @convertedseqs,$converted;
    }
    
    # this is a dirty, dirty hack: the bioperl wrapper for muscle craps out
    # when 'profile' is one of its hardcoded @MUSCLE_SWITCHES with our version
    # of the muscle command line program, so we filter out that switch here
    @Bio::Tools::Run::Alignment::Muscle::MUSCLE_SWITCHES = grep { $_ ne 'profile' } @Bio::Tools::Run::Alignment::Muscle::MUSCLE_SWITCHES;
    
    # TODO: make this more flexible? E.g. also allow using clustal, or t-coffee or whatever...?
    my $muscle = Bio::Tools::Run::Alignment::Muscle->new;
    my $align=$muscle->align(\@convertedseqs);
    return $align;
}

1;

=head1 NAME

Bio::Phylo::PhyLoTA::Service::SequenceGetter - Sequence Getter

=head1 DESCRIPTION

Gets sequences for all species from Genbank (www.ncbi.nlm.nih.gov).

=cut
