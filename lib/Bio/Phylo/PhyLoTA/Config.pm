package Bio::Phylo::PhyLoTA::Config;
use strict;
use warnings;
use Config::Tiny;

our $AUTOLOAD;
my $SINGLETON;

sub new {
    if ( not $SINGLETON ) {
        return $SINGLETON = shift->read(@_);    
    }
    else {
        return $SINGLETON;
    }
}

sub read {
    my $self = shift;
    my $file = shift || "$ENV{PHYLOTA_ROOT}/conf/phylota.ini";
    my $conf = Config::Tiny->read($file);
    if ( my $error = Config::Tiny->errstr ) {
        die $error;
    }
    if ( ref $self ) {
        $self->{'_conf'} = $conf;
    }
    else {
        my $class = $self;
        $self = bless { '_conf' => $conf }, $class;
    }
    return $self;
}

sub currentGBRelease {
    my $self = shift;
    if ( ! $self->GB_RELNUM ) {
        my $file = $self->GB_RELNUM_FILE;
        open my $fh, '<', $file or die $!;
        while(<$fh>) {
            chomp;
            $self->GB_RELNUM($_) if $_;
        }
        close $fh;
    }
    return $self->GB_RELNUM;
}

sub currentGBReleaseDate {    
    my $self = shift;
    if ( ! $self->GB_RELNUM_DATE ) {
        my $file = $self->GB_RELNUM_DATE_FILE;
        open my $fh, '<', $file or die $!;
        while(<$fh>) {
            chomp;
            $self->GB_RELNUM_DATE($_) if $_;
        }
        close $fh;
    }
    return $self->GB_RELNUM_DATE;
}

sub AUTOLOAD {
    my $self = shift;
    my $root = $self->{'_conf'}->{'_'};
    my $key = $AUTOLOAD;
    $key =~ s/.+://;
    if ( exists $root->{$key} ) {
        $root->{$key} = shift if @_;
        return $root->{$key};
    }
    else {
        warn "Unknown key: $key" unless $key =~ /^[A-Z]+$/;
    }
}

1;