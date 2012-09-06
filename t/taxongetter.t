#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';
use Bio::Phylo::PhyLoTA::Config;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Matrices::Matrix;
use Bio::Phylo::PhyLoTA::Service::SequenceGetter;
use Data::Dumper;

my $log = Bio::Phylo::Util::Logger->new(
	'-level' => INFO,
	'-class' => 'Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector',
);
$log->VERBOSE(
	'-level' => INFO,
	'-class' => 'main',
);

# the first tests: can we use and instantiate the MarkersAndTaxaSelector
BEGIN { use_ok('Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector'); }
my $mts = new_ok('Bio::Phylo::PhyLoTA::Service::MarkersAndTaxaSelector');

# we are going to read the text files in the results/specieslists dir,
# so we first need its location based on the system config
my $config = Bio::Phylo::PhyLoTA::Config->new;
my $file = $config->RESULTS_DIR . '/specieslists/species_list_animals_AD.txt';

# read names from file, clean line breaks
open my $fh, '<', $file or die $!;
my @names = <$fh>;
chomp(@names);

# this will take some time to do the TNRS
#my @result = $mts->get_nodes_for_names(@names);
#ok( @result );
#print $_->ti, "\n" for @result;

# these are the tis we'd expect to get back
my @tis = qw(753168 254365 987932 988015 171592 171594 987942 722666 214311 9659
111881 29065 34924 722673 211598 100825 45807 166085 988043 987431 988048 988044
987439 988049 190359 104444 934882 596532 56325 100826 987895 987897 934856
934852 753216 988129 59474 987028 190360 33409 571782 942286 366085 111912
287261 287345 875924 287380 110799 987956 988113 938192 214143 129397 987032
104445 186548 56324 986982 215162 48849 987874 929971 42275 988035 216862 317151
9187 55661 171605 934813 986953 54292 934859 987903 80427 9160 987959 753189
10129 95620 9993 934863 111916 381128 187436 73324 111917 34708 55149 525771
934866 405024 229917 505408 405023 326958 988094 191398 127946 873506 405022
189913 988071 48155 987992 208071 399537 934883 8384 82595 178818 8443 934949
753202 116150 987881 753153 689061 8954 987882 8964 987883 216225 56783 137523
447135 64668 876073 876076 204505 405009 520884 987994 722665 987948 934826
987946 987949 706635 344928 320102 987951 415331 987012 301543 242267 7116
722659 216216 987975 987005 179674 934945 30374 171802 110791 942218 46979
934918 326945 326947 100819 990991 987945 988024 218760 987425 57571 875885
326963 412107 104490 123850 9627 405009 73327 405034 988087 8524 9683 366038
934894 986954 88112 9052 203773 56789 56790 197113 987011 171585 187859 203779
79468 174269 78633 876055 464721 214073 722661 986994 797160 753204 934829 64459
988002 987434 357595 37610 113334 111940 987996 934940 8407 987954 175133 55055
104474 116130 988009 685387 282009 689501 282391 934903 875882 279966 146086
441325 73405 320238 1007708 111891 36278 197171 9091 987869 9662 722655 55057
9983 29058 934908 542982 156567 116126 59472 72545 219811 987436 10090 156563
429750 194188 987931 36286 103375 542985 8032 988174 72779 48893 214030 56781
987911 987910 45802 504296 111894 356903 84560 30422 588438 111071 270466 45804
515219 100457 37595 9823 113335 113340 987862 987863 9157 987865 111896 987861
151312 62282 71817 498208 73330 287208 753147 73333 8934 987891 201445 988027
189526 987974 987447 208978 208980 753485 228011 69510 344233 413656 104503
230656 113337 242262 326960 36802 104515 36723 237442 934828 191421 988018
988019 7524 151304 596532 441235 150913 934897 987418 988152 988036 244290 8585
88116 111924 113342 722671 9938 219781 292571 111925 374600 50251 874455 119269
78609 67763 104447 43551 145610 150234 934923 987449 383689 80460 934929 987981
934902 934876 986992 242269 155166 980960 934931 522836 405032 7434 30397 266947
218773 580924 282377 214382 934872 236853 145125 171548 208016 236860 171587
111821 8706 934904 109485 875884 987967 987426 52810 7098 8895 73322 43518 9986
68468 716740 423510 211599 111902 721167 988141 934920 934934 111914 934840
76193 988110 644661 988089 9079 36239 509483 126069 48149 30390 13123 36169
326957 942213 30194 29092 332931 48150 74081 47230 722662 987936 987937 987938
987939 987940 72248 78622 64176 78897 988010 104470 875886 938185 988014 184257
988011 43337 104460 69508 111904 203782 358815 9858 934824 104486 522848 88454
113330 934870 102178 242259 265386 987983 987984 987427 987991 8022 269649
987988 75838 987421 190347 986988 282031 934835 30374 934836 43150 509358 181117
876054 42254 320256 934838 227532 116128 326949 987888 585988 8839 242256 111811
689280 988124 405022 987917 132600 190364 138070 268709 268716 265384 265388
215315 988062 9054 53277 36241 127875 873508 62280 689058 987009 8957 326962
111938);

my $schema = Bio::Phylo::PhyLoTA::DAO->new;
my @nodes = map { $schema->resultset('Node')->find($_) } @tis;
my @clusters = $mts->get_clusters_for_nodes(@nodes);
ok( @clusters );

# now build the alignment for the biggest one
my $i = 1;
my %ti = map { $_ => 1 } @tis;

# iterate over matching clusters
for my $cl ( @clusters ) {
	$log->info("going to fetch sequences for cluster $cl");
	
	# fetch ALL sequences for the cluster
	my $sg = Bio::Phylo::PhyLoTA::Service::SequenceGetter->new;
	my @seqs = $sg->filter_seq_set($sg->get_sequences_for_cluster_object($cl));
	$log->info("fetched ".scalar(@seqs)." sequences");
	
	# keep only the sequences for our taxa
	my @matching = grep { $ti{$_->ti} } @seqs;
	
	# let's not keep the singletons
	if ( scalar @matching > 3 ) {
		
		# this runs muscle, so should be on your PATH
		$log->info("going to align sequences");
		my $aln = $sg->align_sequences(@matching);
		$log->info("done aligning");
		
		# convert AlignmentI to matrix for pretty NEXUS generation
		my $m = Bio::Phylo::Matrices::Matrix->new_from_bioperl($aln);
		
		# iterate over all matrix rows
		$m->visit(sub{					
			my $row = shift;
			
			# this is set by the alignment method
			my $gi = $row->get_name;
			
			# here we back track to get our taxon names
			my $seq = $schema->resultset('Seq')->find($gi);
			my $ti = $seq->ti;
			my $taxon;
			if ( not ref $ti ) {
				$taxon = $schema->resultset('Node')->find($ti);
			}
			else {
				$taxon = $ti;
			}
			my $name = $taxon->taxon_name . " $gi";
			$name =~ s/ /_/;
			$row->set_name($name); # e.g. Homo_sapiens_2312
		});
		
		# create taxa block, which is alphabetized
		my $taxa = $m->make_taxa;
		
		# sort matrix
		my @sorted = sort { $a->get_name cmp $b->get_name } @{ $m->get_entities };
		$m->clear;
		$m->insert($_) for @sorted;
		
		# create out file name
		my $outfile = $file;
		$outfile =~ s/\.txt$/.$i.nex/;
		open my $outfh, '>', $outfile or die $!;
		print $outfh "#NEXUS\n", $taxa->to_nexus, $m->to_nexus;
		close $outfh;
		$log->info("wrote alignment to $outfile");
		$i++;
	}
}