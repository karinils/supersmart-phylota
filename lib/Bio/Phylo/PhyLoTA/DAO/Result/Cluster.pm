package Bio::Phylo::PhyLoTA::DAO::Result::Cluster;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Bio::Phylo::PhyLoTA::DAO::Result::Cluster

=cut

__PACKAGE__->table("clusters");

=head1 ACCESSORS

=head2 ti_root

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 ci

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 cl_type

  data_type: 'enum'
  extra: {list => ["node","subtree"]}
  is_nullable: 1

=head2 n_gi

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 n_ti

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 pi

  data_type: 'tinyint'
  is_nullable: 1

=head2 minlength

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 maxlength

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 maxaligndens

  data_type: 'float'
  is_nullable: 1

=head2 ci_anc

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 seed_gi

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 q

  data_type: 'float'
  is_nullable: 1

=head2 tc

  data_type: 'float'
  is_nullable: 1

=head2 clustalw_tree

  data_type: 'longtext'
  is_nullable: 1

=head2 muscle_tree

  data_type: 'longtext'
  is_nullable: 1

=head2 strict_tree

  data_type: 'longtext'
  is_nullable: 1

=head2 clustalw_res

  data_type: 'float'
  is_nullable: 1

=head2 muscle_res

  data_type: 'float'
  is_nullable: 1

=head2 strict_res

  data_type: 'float'
  is_nullable: 1

=head2 ortho

  data_type: 'tinyint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ti_root",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "ci",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "cl_type",
  {
    data_type => "enum",
    extra => { list => ["node", "subtree"] },
    is_nullable => 1,
  },
  "n_gi",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "n_ti",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "pi",
  { data_type => "tinyint", is_nullable => 1 },
  "minlength",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "maxlength",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "maxaligndens",
  { data_type => "float", is_nullable => 1 },
  "ci_anc",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "seed_gi",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "q",
  { data_type => "float", is_nullable => 1 },
  "tc",
  { data_type => "float", is_nullable => 1 },
  "clustalw_tree",
  { data_type => "longtext", is_nullable => 1 },
  "muscle_tree",
  { data_type => "longtext", is_nullable => 1 },
  "strict_tree",
  { data_type => "longtext", is_nullable => 1 },
  "clustalw_res",
  { data_type => "float", is_nullable => 1 },
  "muscle_res",
  { data_type => "float", is_nullable => 1 },
  "strict_res",
  { data_type => "float", is_nullable => 1 },
  "ortho",
  { data_type => "tinyint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-26 14:28:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aOIPYTQjlgtypxcbLW9Frw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
