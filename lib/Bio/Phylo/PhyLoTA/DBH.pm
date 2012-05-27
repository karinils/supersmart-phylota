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
        $args{'-rdbms'}    ||= $config->RDBMS;
        $args{'-database'} ||= $config->DATABASE;
        $args{'-host'}     ||= $config->HOST;
        $args{'-user'}     ||= $config->USER;
        $args{'-pass'}     ||= $config->PASS;
        $args{'-dsn'} = sprintf('DBI:%s:database=%s;host=%s', @args{qw[-rdbms -database -host]});
        $args{'-dbh'} = DBI->connect($args{'-dsn'},@args{qw[-user -pass]});
        $SINGLETON = \%args;
        bless $SINGLETON, $class;
    }
    return $SINGLETON;
}

sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.+://;
    if ( exists $self->{"-$method"} ) {
        return $self->{"-$method"};
    }
    else {
        $self->{'-dbh'}->$method(@_) if $self->{'-dbh'};
    }    
}

1;