# this is an object oriented perl module

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
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

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

=head2 division

  data_type: 'varchar'
  is_nullable: 1
  size: 5

=head2 acc_date

  data_type: 'date'
  is_nullable: 1

=head2 gbrel

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 def

  data_type: 'text'
  is_nullable: 1

=head2 seq

  data_type: 'mediumtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "gi",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "ti",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "acc",
  { data_type => "varchar", is_nullable => 1, size => 12 },
  "acc_vers",
  { data_type => "smallint", extra => { unsigned => 1 }, is_nullable => 1 },
  "length",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "division",
  { data_type => "varchar", is_nullable => 1, size => 5 },
  "acc_date",
  { data_type => "date", is_nullable => 1 },
  "gbrel",
  { data_type => "smallint", extra => { unsigned => 1 }, is_nullable => 1 },
  "def",
  { data_type => "text", is_nullable => 1 },
  "seq",
  { data_type => "mediumtext", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("gi");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-29 00:09:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KMVaLLKni4EKqpT1DqTR6w


# You can replace this text with custom content, and it will be preserved on regeneration
use Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector;

my $mts = Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector->new;

sub get_id {
	shift->gi;
}

sub id {
	shift->gi;
}

sub get_taxon {
	my $self = shift;
	my $ti = $self->ti;
	return $mts->find_node($ti);
}

sub get_char {
	my $self = shift;
	my $seq = $self->seq;
	if ( wantarray ) {
		return split //, $seq;
	}
	else {
		return $seq;
	}
}

sub get_entities {
	my @char = shift->get_char;
	return \@char;
}

sub get_name { shift->def }

1;
