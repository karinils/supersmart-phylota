package Bio::Phylo::PhyLoTA::Service;
use strict;
use warnings;
use Moose;
use Bio::Phylo::PhyLoTA::DAO;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger;

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

1;