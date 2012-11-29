# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::DAO::Result::Node;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Bio::Phylo::PhyLoTA::DAO::Result::Node

=cut

__PACKAGE__->table("nodes");

=head1 ACCESSORS

=head2 ti

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 ti_anc

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 terminal_flag

  data_type: 'tinyint'
  is_nullable: 1

=head2 rank_flag

  data_type: 'tinyint'
  is_nullable: 1

=head2 model

  data_type: 'tinyint'
  is_nullable: 1

=head2 taxon_name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 common_name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 rank

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 n_gi_node

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_gi_sub_nonmodel

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_gi_sub_model

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_clust_node

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_clust_sub

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_piclust_sub

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_sp_desc

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_sp_model

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_leaf_desc

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_otu_desc

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ti",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "ti_anc",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "terminal_flag",
  { data_type => "tinyint", is_nullable => 1 },
  "rank_flag",
  { data_type => "tinyint", is_nullable => 1 },
  "model",
  { data_type => "tinyint", is_nullable => 1 },
  "taxon_name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "common_name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "rank",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "n_gi_node",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_gi_sub_nonmodel",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_gi_sub_model",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_clust_node",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_clust_sub",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_piclust_sub",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_sp_desc",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_sp_model",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_leaf_desc",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_otu_desc",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("ti");

=head1 RELATIONS

=head2 clusters

Type: has_many

Related object: L<Bio::Phylo::PhyLoTA::DAO::Result::Cluster>

=cut

__PACKAGE__->has_many(
  "clusters",
  "Bio::Phylo::PhyLoTA::DAO::Result::Cluster",
  { "foreign.ti_root" => "self.ti" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 specimens

Type: has_many

Related object: L<Bio::Phylo::PhyLoTA::DAO::Result::Specimen>

=cut

__PACKAGE__->has_many(
  "specimens",
  "Bio::Phylo::PhyLoTA::DAO::Result::Specimen",
  { "foreign.ti" => "self.ti" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-29 21:38:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gASJ9/nj5PXGPX9jZT2prA


# You can replace this text with custom content, and it will be preserved on regeneration
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Forest::NodeRole;
use Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;
push @Bio::Phylo::PhyLoTA::DAO::Result::Node::ISA, 'Bio::Phylo::Forest::NodeRole';

my $mts = Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector->new;
my %tree;

sub table {
	my $class = shift;
	my $table = shift;
	my $release = Bio::Phylo::PhyLoTA::Config->new->currentGBRelease;
	$class->SUPER::table( $table . '_' . $release );
}

sub get_parent {
	my $self = shift;
	if ( $self->get_generic('root') ) {
		return;
	}
	if ( my $parent_ti = $self->ti_anc ) {
		return $mts->find_node($parent_ti);
	}
	return;
}

sub set_parent { return shift }

sub get_children {
	my $self = shift;
	my $ti = $self->ti;
	my @children = $mts->search_node( { ti_anc => $ti } )->all;
	return \@children;
}

sub get_branch_length { return }

sub set_branch_length { return shift }

sub get_id { shift->ti }

sub set_tree {
	my ( $self, $tree ) = @_;
	$tree{ $self->get_id } = $tree;
	return $self;
}

sub get_tree { $tree{ shift->get_id } }

sub get_name { shift->taxon_name }

1;
