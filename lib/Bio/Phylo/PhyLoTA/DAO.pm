package Bio::Phylo::PhyLoTA::DAO;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-05-26 14:28:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qy8gwA4ReJ1Jez7iqtYMBQ


# You can replace this text with custom content, and it will be preserved on regeneration
use Bio::Phylo::PhyLoTA::Config;
my $SINGLETON;
sub new {
	if ( not $SINGLETON ) {
		my $class = shift;
		my $c = Bio::Phylo::PhyLoTA::Config->new;
		my $dsn = sprintf 'DBI:%s:database=%s;host=%s', $c->RDBMS, $c->DATABASE, $c->HOST;
		$SINGLETON = $class->connect( $dsn, $c->USER, $c->PASS );
	}
	return $SINGLETON;
}
1;
