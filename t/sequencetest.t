use Bio::Phylo::PhyLoTA::DAO;

# connect to the database
my $schema = Bio::Phylo::PhyLoTA::DAO->new;
# ($schema->resultset('Seq')) = retive sequences. find(296721283) = get sequence with gi 296721283
my $seq = $schema->resultset('Seq')->find(296721283);
# print the taxon identifier
print $seq->ti;

my $node=$schema->resultset('Node')->find($seq->ti);
print "\n", $node->taxon_name;