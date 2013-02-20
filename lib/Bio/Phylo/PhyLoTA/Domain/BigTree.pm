# this is an object oriented perl module

package Bio::Phylo::PhyLoTA::Domain::BigTree;
use strict;
use warnings;
use Cwd;
use File::Copy;
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
    
    # these are normally derived from the config file
    my $work_dir   = $args{'-work_dir'}   || $conf->WORK_DIR;
    my $examl_bin  = $args{'-examl_bin'}  || $conf->EXAML_BIN;
    my $parser_bin = $args{'-parser_bin'} || $conf->PARSER_BIN;
    my $examl_args = $args{'-examl_args'} || $conf->EXAML_ARGS;
    
    # create outfile from infile, if not provided
    my $outfile = $args{'-outfile'} || "${seqfile_basename}.dnd";
    
    # first create the binary representation of the seq file, if it doesn't exist yet
    if ( not -e "${work_dir}/${seqfile_basename}.binary" ) {
        $log->info("going to create binary compressed alignment file ${work_dir}/${seqfile_basename}.binary");
        chdir $work_dir;
        my $command = "$parser_bin -s $seqfile_basename -n $seqfile_basename -m DNA > /dev/null";
        $log->info("going to run '$command'");
        system( $command ) == 0 or throw 'BadArgs' => $?;
        chdir $cwd;
    }
    else {
        $log->info("binary compressed alignment file ${work_dir}/${seqfile_basename}.binary already existed");
    }
    
    # copy the starting tree to the working dir if it's not already there
    if ( not -e "${work_dir}/${treefile_basename}" ) {
        $log->info("copying $treefile to $work_dir");
        copy( $treefile, "${work_dir}/${treefile_basename}" );
    }
    
    # now run the tree search
    {
        chdir $work_dir;
        my $command = "$examl_bin $examl_args -s ${seqfile_basename}.binary -t $treefile_basename -n $outfile > /dev/null";
        $log->info("going to run '$command'");
        system( $command ) == 0 or throw 'BadArgs' => $?;
        chdir $cwd;
    }
    return "$work_dir/ExaML_result.$outfile";
}


1;

=head1 NAME

Bio::Phylo::PhyLoTA::Domain::BigTree - Big Tree

=head1 DESCRIPTION

Tree (string) in Newick format having support values and node ages. Taxon ID’s for 
genera as leaf labels.

=cut

