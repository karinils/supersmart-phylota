# this is an object oriented perl module
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

=head1 NAME

Bio::Phylo::PhyLoTA::DAO - The database schema

=head1 SYNOPSIS

    use Bio::Phylo::PhyLoTA::DAO;
    
    my $schema = Bio::Phylo::PhyLoTA::DAO->new;
    my $node = $schema->resultset('Node')->find(9606);
    while($node) {
        print $node->taxon_name, "\n";
        my $clusters = $node->clusters;
        while( my $c = $clusters->next ) {
            my $gis = $schema->resultset('CiGi')->search({ clustid => $c->ci });
            while ( my $g = $gis->next ) {
                print $g->gi, "\n";
            }
        }
        $node = $schema->resultset('Node')->find($node->ti_anc);
    }

=head1 DESCRIPTION

We use a relational schema implemented in MySQL with a small number of tables.
The 'seqs' table is used across all releases of the database. Other tables have
a suffix consisting of '_xx' indicating the GenBank release number.

The 'nodes_xx' table is constructed in part from NCBI's taxonomy flatfiles and
in part from calculations and summaries built by us. The 'seqs' table is data
taken directly from GenBank sequence flatfiles. The 'clusters_xx' contains
summary information obtained by the clustering pipeline, and information about
individual clusters is stored in 'cigi_xx'. Summary statistics on the entire
cluster set are calculated and stored in 'summary_stats'.

=cut

use Bio::Phylo::PhyLoTA::DBH;
my $SINGLETON;
sub new {
	if ( not $SINGLETON ) {
		my $class = shift;
		my $dbh = Bio::Phylo::PhyLoTA::DBH->new;
		$SINGLETON = $class->connect( $dbh->dsn, $dbh->user, $dbh->pass );
	}
	return $SINGLETON;
}
1;
