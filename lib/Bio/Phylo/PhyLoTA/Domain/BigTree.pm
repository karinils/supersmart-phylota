# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::BigTree;
use strict;
use warnings;
use Cwd;
use File::Basename;
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';

my $conf = Bio::Phylo::PhyLoTA::Config->new;
my $log  = Bio::Phylo::Util::Logger->new;
my $cwd  = getcwd();

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}

sub build_tree {
    my $self = shift;
    my %args = @_;
    
    # these are required arguments
    my $seqfile  = $args{'-seq_file'}  or throw 'BadArgs' => "need -seq_file argument";
    my $treefile = $args{'-tree_file'} or throw 'BadArgs' => "need -tree_file argument";
    my $seqfile_basename = basename($seqfile);
    my $treefile_basename = basename($treefile);
    
    # there are optionally derived from the config file
    my $work_dir   = $args{'-work_dir'}   || $conf->WORK_DIR;
    my $examl_bin  = $args{'-examl_bin'}  || $conf->EXAML_BIN;
    my $parser_bin = $args{'-parser_bin'} || $conf->PARSER_BIN;
    my $examl_args = $args{'-examl_args'} || $conf->EXAML_ARGS;
    
    # create outfile from infile, if not provided
    my $outfile = $args{'-outfile'} || "${seqfile}.dnd";
    
    # first create the binary representation of the seq file, if it doesn't exist yet
    if ( not -e "${work_dir}/${$seqfile_basename}.binary" ) {
        chdir $work_dir;
        system( $parser_bin, '-s', $seqfile, '-n', "${$seqfile_basename}.binary", '-m', 'DNA' ) == 0 or throw 'BadArgs' => $?;
        chdir $cwd;
    }
    
    # now run the tree search
    {
        chdir $work_dir;
        system( $examl_bin, $examl_args, '-s', "${$seqfile_basename}.binary", '-t', $treefile_basename, '-n', $outfile ) == 0 or throw 'BadArgs' => $?;
    }
    return $outfile;
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::BigTree - Big Tree

=head1 DESCRIPTION

Tree (string) in Newick format having support values and node ages. Taxon ID’s for 
genera as leaf labels.

=cut

