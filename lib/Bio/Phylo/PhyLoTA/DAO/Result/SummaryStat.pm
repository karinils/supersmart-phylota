# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::DAO::Result::SummaryStat;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Bio::Phylo::PhyLoTA::DAO::Result::SummaryStat

=cut

__PACKAGE__->table("summary_stats");

=head1 ACCESSORS

=head2 gb_release

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 gb_rel_date

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 n_gis

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_nodes

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_nodes_term

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_clusts_node

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_clusts_sub

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_nodes_with_sequence

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_clusts

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_pi_clusts

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_singleton_clusts

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_large_gi_clusts

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_large_ti_clusts

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_largest_gi_clust

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_largest_ti_clust

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 alignments_done

  data_type: 'tinyint'
  is_nullable: 1

=head2 trees_done

  data_type: 'tinyint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "gb_release",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "gb_rel_date",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "n_gis",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_nodes",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_nodes_term",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_clusts_node",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_clusts_sub",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_nodes_with_sequence",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_clusts",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_pi_clusts",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_singleton_clusts",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_large_gi_clusts",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_large_ti_clusts",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_largest_gi_clust",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_largest_ti_clust",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "alignments_done",
  { data_type => "tinyint", is_nullable => 1 },
  "trees_done",
  { data_type => "tinyint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-29 00:09:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:80HTidbU/fZX63yFE/r4wg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
