package Bio::Phylo::PhyLoTA::DBH;
use strict;
use warnings;
use DBI;
use Bio::Phylo::PhyLoTA::Config;

my $SINGLETON;
our $AUTOLOAD;

sub new {
    my $class = shift;
    my %args  = @_;
    if ( not $SINGLETON ) {
        my $config   = Bio::Phylo::PhyLoTA::Config->new;
        my $rdbms    = $args{'-rdbms'}    || $config->RDBMS    || 'mysql';
        my $database = $args{'-database'} || $config->DATABASE || 'phylota';
        my $host     = $args{'-host'}     || $config->HOST     || 'localhost';
        my $user     = $args{'-user'}     || $config->USER     || 'sanderm';
        my $passwd   = $args{'-pass'}     || $config->PASSWD   || 'phylota';
        my $dbh = DBI->connect("DBI:$rdbms:database=$database;host=$host",$user,$passwd);
        $SINGLETON = \$dbh;
        bless $SINGLETON, $class;
    }
    return $SINGLETON;
}

sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.+://;
    $$self->$method(@_);
}

1;