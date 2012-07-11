#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=1G
#$ -l h_vmem=1G
#$ -M sanderm@email.arizona.edu
#$ -m e
# Be sure to enable email warnings because otherwise it is hard to detect the occasional vmem errors
# Notice the -j y argument combines STDERR and STDOUT output but doesn't really help with the vmem errors that kill these jobs sometimes
# sge script to write a two column able that will have ti and ci ids for all PI clusters
use DBI;
use pb;
use lib '/home/sanderm/blast'
  ; # have to tell PERL (running on slave nodes) where to find the module (this is on the head node)
my $configFile = "/home/sanderm/blast/pb.conf";    #default
if ( !( -e $configFile ) ) { die "Missing config file\n"; }
%pbH     = %{ pb::parseConfig($configFile) };
$release = pb::currentGBRelease();
my $dbh =
  DBI->connect( "DBI:mysql:database=$pbH{MYSQL_DATABASE};host=$pbH{MYSQL_HOST}",
    $pbH{MYSQL_USER}, $pbH{MYSQL_PASSWD} );
$clusterTable  = "clusters_$release";
$clusterListFn = "$pbH{ALIGNED_DIR}/clustersToBeAlignedList\_$release";
open FH, ">$clusterListFn";
$sql = "select ti_root, ci from $clusterTable where PI=1";
$sh  = $dbh->prepare($sql);
$sh->execute;

while ( $rowHRef =
    $sh->fetchrow_hashref ) # only returns one row (presumably) here and next...
{
    $tiRoot = $rowHRef->{ti_root};
    $ci     = $rowHRef->{ci};
    print FH "$tiRoot\t$ci\n";
}
$sh->finish;
