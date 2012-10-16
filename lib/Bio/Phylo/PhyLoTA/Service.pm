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
my $logger = Bio::Phylo::Util::Logger->new;

sub find_seq {
	my ( $self, $gi ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Seq')->find($gi);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;
}

sub search_seq {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Seq')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub single_seq {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Seq')->single($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub find_node {
	my ( $self, $ti ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Node')->find($ti);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub search_node {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Node')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub single_node {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Node')->single($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub single_cluster {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('Cluster')->single($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub search_ci_gi {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('CiGi')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

sub search_inparanoid {
	my ( $self, $clause ) = @_;
	my $result;
	eval {
		$result = $schema->resultset('InParanoid')->search($clause);
	};
	if ( $@ ) {
		throw 'BadArgs' => $@;
	}
	if ( not $result ) {
		$logger->warn("no result!");
	}
	return $result;	
}

1;