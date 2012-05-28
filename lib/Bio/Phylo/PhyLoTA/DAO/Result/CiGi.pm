package Bio::Phylo::PhyLoTA::DAO::Result::CiGi;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Bio::Phylo::PhyLoTA::DAO::Result::CiGi

=cut

__PACKAGE__->table("ci_gi");

=head1 ACCESSORS

=head2 ti

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 clustid

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 cl_type

  data_type: 'enum'
  extra: {list => ["node","subtree"]}
  is_nullable: 1

=head2 gi

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 ti_of_gi

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ti",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "clustid",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "cl_type",
  {
    data_type => "enum",
    extra => { list => ["node", "subtree"] },
    is_nullable => 1,
  },
  "gi",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "ti_of_gi",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 RELATIONS

=head2 ti

Type: belongs_to

Related object: L<Bio::Phylo::PhyLoTA::DAO::Result::Node>

=cut

__PACKAGE__->belongs_to(
  "ti",
  "Bio::Phylo::PhyLoTA::DAO::Result::Node",
  { ti => "ti" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 clustid

Type: belongs_to

Related object: L<Bio::Phylo::PhyLoTA::DAO::Result::Cluster>

=cut

__PACKAGE__->belongs_to(
  "clustid",
  "Bio::Phylo::PhyLoTA::DAO::Result::Cluster",
  { ci => "clustid" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 gi

Type: belongs_to

Related object: L<Bio::Phylo::PhyLoTA::DAO::Result::Seq>

=cut

__PACKAGE__->belongs_to(
  "gi",
  "Bio::Phylo::PhyLoTA::DAO::Result::Seq",
  { gi => "gi" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-28 21:25:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X6dH5ItvJTDYLq1h0ll7PQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
