package Bio::Phylo::PhyLoTA::Service;
use strict;
use warnings;
use Moose;
use Bio::Phylo::PhyLoTA::DAO;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';

has 'schema'  => (
    'is'      => 'rw',
    'isa'     => 'Bio::Phylo::PhyLoTA::DAO',
    'default' => sub { Bio::Phylo::PhyLoTA::DAO->new },
);

has 'config'  => (
    'is'      => 'rw',
    'isa'     => 'Bio::Phylo::PhyLoTA::Config',
    'default' => sub { Bio::Phylo::PhyLoTA::Config->new },
);

has 'logger'  => (
    'is'      => 'rw',
    'isa'     => 'Bio::Phylo::Util::Logger',
    'default' => sub { Bio::Phylo::Util::Logger->new },
);

my $schema = Bio::Phylo::PhyLoTA::DAO->new;

sub find_seq {
	my ( $self, $gi ) = @_;
	eval {
		return $schema->resultset('Seq')->find($gi);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
}

sub search_seq {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('Seq')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
}

sub single_seq {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('Seq')->single($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

sub find_node {
	my ( $self, $ti ) = @_;
	eval {
		return $schema->resultset('Node')->find($ti);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

sub search_node {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('Node')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

sub single_node {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('Node')->single($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

sub single_cluster {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('Cluster')->single($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

sub search_ci_gi {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('CiGi')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

sub search_inparanoid {
	my ( $self, $clause ) = @_;
	eval {
		return $schema->resultset('InParanoid')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}	
}

1;