# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;
use strict;
use warnings;
use JSON;
use Moose;
use URI::Escape;
use Data::Dumper;
use LWP::UserAgent;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::PhyLoTA::DAO;

extends 'Bio::Phylo::PhyLoTA::Service';

=head1 NAME

Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector - Markers and Taxa Selector

=head1 DESCRIPTION

Selects optimal set of taxa and markers based on #markers/sp, coverage on matrix
(total missing data). User can change threshold.

=cut

# URL for the taxonomic name resolution service
my $TNRS_URL = 'http://api.phylotastic.org/tnrs/submit';
my $TNRS_RETRIEVE = 'http://api.phylotastic.org/tnrs/retrieve/';

# defaults for web service
my $timeout = 60;
my $wait    = 5;

# this is used to create other objects, i.e. projects and taxa
my $fac = Bio::Phylo::Factory->new;

# this is used for logging messages
my $log = Bio::Phylo::Util::Logger->new;

=over

=item get_nodes_for_names

Accepts a list of name string, does TNRS on them and returns the equivalent
Node objects from the database.

=cut

sub get_nodes_for_names {
    my ( $self, @names ) = @_;
    
    # Resulting nodes
    my @nodes;
    
    # iterate over supplied names
    for my $name ( @names ) {
        $log->info("going to search for name '$name'");
        
        # do we have an exact match?
    	my $node = $self->single_node( { taxon_name => $name } );
        
        # no exact match if ->single returns undef (i.e. false)
        if ( not $node ) {
            $log->info("no exact match for '$name' in local database");
            
            # search the web service
            if ( my $id = $self->_do_tnrs_search($name) ) {
               $node = $self->find_node($id);
               $log->info("found match for $name through TNRS");
            }
            else {
                $log->warn("couldn't find name $name anywhere!");
            }
        }
        else {
            $log->info("found exact match for $name in local database");
        }
        
        # store result
        push @nodes, $node if $node;        
    }
    
    # return results
    return @nodes;
}

=item get_clusters_for_nodes

Given a list of Node objects, returns the clusters that contain these Nodes in
order of decreasing inclusiveness.

Note: if this query runs really, really slowly it is because your version of the
database does not yet have an index on ci_gi.ti_of_gi

To fix this:

mysql> ALTER TABLE ci_gi ADD INDEX(ti_of_gi);

=cut

sub get_clusters_for_nodes {
    my ( $self, @nodes ) = @_;
    my $c = {};
    my @clusters;
    my $counter = 1;
    
    # iterate over nodes
    for my $node ( @nodes ) {
        $log->info("query completion: $counter/".scalar(@nodes));
        $log->debug("finding clusters for ".$node->ti);
        
        # find ci_gi intersection records for this node's ti
        my @cigis = $self->search_ci_gi({ ti_of_gi => $node->ti });
        
        # iterate over matches
        for my $cigi ( @cigis ) {
            
            # store these for re-use: their combination is the composite
            # key for fetch clusters from the clusters table
            my $ti      = $cigi->ti;
            my $clustid = $cigi->clustid;
            my $cl_type = $cigi->cl_type;
            $log->debug("ti => $ti, clustid => $clustid, cl_type => $cl_type");
            
            # build path
            $c->{$ti} = {} unless $c->{$ti};
            $c->{$ti}->{$clustid} = {} unless $c->{$ti}->{$clustid};
            
            push @clusters, {
                'ti'      => $ti,
                'clustid' => $clustid,
                'cl_type' => $cl_type,
            } unless $c->{$ti}->{$clustid}->{$cl_type}++;
        }
        $counter++;
    }
    
    # schwartzian transform
    return
    map {{
        'ti'      => $_->{ti},
        'clustid' => $_->{clustid},
        'cl_type' => $_->{cl_type},
    }}
    sort {
        $b->{cover} <=> $a->{cover}
    }
    map {{
        'ti'      => $_->{ti},
        'clustid' => $_->{clustid},
        'cl_type' => $_->{cl_type},
        'cover'   => $c->{ $_->{ti} }->{ $_->{clustid} }->{ $_->{cl_type} }
    }} @clusters;
}

=item get_tree_for_nodes

Creates the Bio::Phylo tree that spans these nodes

=cut

sub get_tree_for_nodes {
    my ( $self, @nodes ) = @_;
    my $tree = $fac->create_tree;    
    my $mrca = $tree->get_mrca(\@nodes);
    $mrca->visit_level_order(sub{
       my $node = shift;
       $tree->insert($node);
    });
    $mrca->set_generic( 'root' => 1 );
    return $tree;
}

=begin comment

Private method for querying the TNRS web service

=end comment

=cut

sub _do_tnrs_search {
    my ( $self, $name ) = @_;
    
    # do the request
    my $result = _fetch_url( $TNRS_URL . '?query=' . uri_escape( $name ) );
    my $obj = decode_json($result);
    $log->debug("initial response: ".Dumper($obj));
    
    # start polling
    while(1) {
        
        # we have a final response
        if ( $obj->{'names'} ) {
            if ( my $id = $self->_process_matches($obj->{'names'}) ) {
                $log->info("found id $id for name '$name'");
                return $id; # done
            }
            else {
                return;
            }
        }
        
        # do another cycle
        sleep $wait;
        
        # try to reconstruct the retrieve URL. This seems to be variable.
        my $url;
        if ( $obj->{'uri'} ) {
            $url = $obj->{'uri'};
        }
        elsif ( $obj->{'message'} =~ /Job (\S+) is still being processed./ ) {
            $url = $TNRS_RETRIEVE . $1;
        }
        else {
            die "Don't know how to continue";
        }
        
        my $result = _fetch_url($url);
        $obj = decode_json($result);            
    }    
}

=begin comment

Private method for processing the JSON returned by TNRS

=end comment

=cut

sub _process_matches {
    my ( $self, $names ) = @_;
    for my $name ( @{ $names } ) {
        for my $match ( @{ $name->{'matches'} } ) {
            if ( $match->{'sourceId'} eq 'NCBI' and $match->{'uri'} =~ /(\d+)$/ ) {
                my $id = $1;
                return $id;
            }
        }
    }
    return;
}

=begin comment

Private method to retrieve the contents of a URL

=end comment

=cut

# fetch data from a URL
sub _fetch_url {
	my ( $url ) = @_;
	$log->info("going to fetch $url");
	
	# instantiate user agent
	my $ua = LWP::UserAgent->new;
	$ua->timeout($timeout);
	$log->info("instantiated user agent with timeout $timeout");
	
	# do the request on LWP::UserAgent $ua
	my $response = $ua->get($url);
	
	# had a 200 OK
	if ( $response->is_success or $response->code == 302 ) {
		$log->info($response->status_line);
		my $content = $response->decoded_content;
		return $content;
	}
	else {
		$log->error($url . ' - ' . $response->status_line);
		die $response->status_line;
	}	
}

1;