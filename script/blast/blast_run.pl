#!/usr/bin/perl
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
#$ -l vf=1G
#$ -l h_vmem=1G
#$ -M sanderm@email.arizona.edu
#$ -m n
system "./old_allallblast.pl -q test.fa -t test.fa -c pb.conf -o test.out";

