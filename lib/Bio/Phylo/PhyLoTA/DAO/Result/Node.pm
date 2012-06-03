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


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-29 00:13:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9210Nia2pQOVAf/8pZ/j+w


# You can replace this text with custom content, and it will be preserved on regeneration
use Bio::Phylo::PhyLoTA::Config;
sub table {
	my $class = shift;
	my $table = shift;
	my $release = Bio::Phylo::PhyLoTA::Config->new->currentGBRelease;
	$class->SUPER::table( $table . '_' . $release );
}
1;
