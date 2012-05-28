package Bio::Phylo::PhyLoTA::DBH;
use strict;
use warnings;
use DBI;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger ':levels';

my $SINGLETON;
our $AUTOLOAD;
my $log = Bio::Phylo::Util::Logger->new;

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
        my $dsn_tmpl  = 'DBI:%s:database=%s;host=%s';
        $args{'-dsn'} = sprintf($dsn_tmpl, @args{qw[-rdbms -database -host]});
        $args{'-dbh'} = DBI->connect($args{'-dsn'},@args{qw[-user -pass]});
        $SINGLETON = \%args;
        bless $SINGLETON, $class;
    }
    return $SINGLETON;
}

sub DESTROY {
    my $self = shift;
    $self->disconnect if $self->dbh;
}

sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.+://;
    if ( exists $self->{"-$method"} ) {
        return $self->{"-$method"};
    }
    else {
        if ( not $self->dbh->ping ) {
            $log->warn("handle was disconnected, reconnecting...");
            $self->{'-dbh'} = DBI->connect($self->dsn,$self->user,$self->pass);
        }
        $self->dbh->$method(@_);
    }    
}

1;