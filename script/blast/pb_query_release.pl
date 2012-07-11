#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;
use Bio::Phylo::PhyLoTA::Config;

# process command line arguments
my $configFile;
GetOptions( 'configFile=s' => \$configFile );

# instantiate config object
my $config = Bio::Phylo::PhyLoTA::Config->new($configFile);

# print output
print "The current release setting based on the config file $configFile is ",
    $config->currentGBRelease, "\n";

