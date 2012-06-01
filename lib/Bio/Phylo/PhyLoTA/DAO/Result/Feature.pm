package Bio::Phylo::PhyLoTA::DAO::Result::Feature;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Bio::Phylo::PhyLoTA::DAO::Result::Feature

=cut

__PACKAGE__->table("features");

=head1 ACCESSORS

=head2 feature_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 primary_tag

  data_type: 'varchar'
  is_nullable: 1
  size: 12

=head2 gi

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 gi_feat

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 ti

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 acc

  data_type: 'varchar'
  is_nullable: 1
  size: 12

=head2 acc_vers

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 length

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 codon_start

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 transl_table

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 gene

  data_type: 'text'
  is_nullable: 1

=head2 product

  data_type: 'text'
  is_nullable: 1

=head2 seq

  data_type: 'mediumtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "feature_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "primary_tag",
  { data_type => "varchar", is_nullable => 1, size => 12 },
  "gi",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "gi_feat",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "ti",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "acc",
  { data_type => "varchar", is_nullable => 1, size => 12 },
  "acc_vers",
  { data_type => "smallint", extra => { unsigned => 1 }, is_nullable => 1 },
  "length",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "codon_start",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 1 },
  "transl_table",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 1 },
  "gene",
  { data_type => "text", is_nullable => 1 },
  "product",
  { data_type => "text", is_nullable => 1 },
  "seq",
  { data_type => "mediumtext", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("feature_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-06-01 19:09:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+bHPCm+g+/3ql2wWV9/6YQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
