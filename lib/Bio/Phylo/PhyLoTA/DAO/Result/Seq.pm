package Bio::Phylo::PhyLoTA::DAO::Result::Seq;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Bio::Phylo::PhyLoTA::DAO::Result::Seq

=cut

__PACKAGE__->table("seqs");

=head1 ACCESSORS

=head2 gi

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 ti

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 length

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 division

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 gb_rel_date

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 gb_release

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mol_type

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 def

  data_type: 'longtext'
  is_nullable: 1

=head2 seq

  data_type: 'longtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "gi",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "ti",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "length",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "division",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "gb_rel_date",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "gb_release",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "mol_type",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "def",
  { data_type => "longtext", is_nullable => 1 },
  "seq",
  { data_type => "longtext", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("gi");

=head1 RELATIONS

=head2 ci_gis

Type: has_many

Related object: L<Bio::Phylo::PhyLoTA::DAO::Result::CiGi>

=cut

__PACKAGE__->has_many(
  "ci_gis",
  "Bio::Phylo::PhyLoTA::DAO::Result::CiGi",
  { "foreign.gi" => "self.gi" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-28 21:25:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k0mTNJNK+TSvBmDhApKVKw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
