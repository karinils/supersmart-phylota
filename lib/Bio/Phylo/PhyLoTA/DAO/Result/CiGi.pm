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
  is_nullable: 1

=head2 clustid

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 cl_type

  data_type: 'enum'
  extra: {list => ["node","subtree"]}
  is_nullable: 1

=head2 gi

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 ti_of_gi

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ti",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "clustid",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "cl_type",
  {
    data_type => "enum",
    extra => { list => ["node", "subtree"] },
    is_nullable => 1,
  },
  "gi",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "ti_of_gi",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-26 14:28:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:z0QRPVOketoOzExYfcPFPw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
