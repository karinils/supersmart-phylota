# Configuration for setting up the database and parsing the sequences

# Note that paths should all be absolute because they may get used by tentakel and distributed from head node via NFS
GB_RELNUM_FILE=/home/sanderm/GB_CURRENT_RELEASE/GB_FLATFILES/GB_Release_Number # text file containing the GB release number on which this build is based
ALL_ALL_CHUNK_SIZE=36000					# number of sequences to include in each file to be submitted to parallel all against all BLAST 
GB_TAXONOMY_DIR=/home/sanderm/GB_CURRENT_RELEASE/TAXONOMY

# Configuration settings for interaction with the mysql database for phylota browser
MYSQL_HOST=ceiba.biosci.arizona.edu
MYSQL_USER=sanderm
MYSQL_PASSWD=phylota
MYSQL_DATABASE=phylota

# Configuration for the all against all blast
cutoffClusters=100000
cutoffNumGINode=100000 	# will cluster a node if < this value
cutoffNumGISub =1000000 	# will cluster a subtree if < this value (but these will be nonmodel sequences)
cutoffLengthNuc=7500
cutoffLengthFeatures=7500
UNALIGNED_DIR=/redwood/export/sanderm/unaligned
ALIGNED_DIR=/redwood/export/sanderm/aligned
BLAST_DIR=/opt/bio/ncbi
FASTA_FILE_DIR=/home/sanderm/blast/data	# directory on head node where fasta files for all-all blast are kept, and where formatdb files will be made
SLAVE_DATA_DIR=/state/partition1/sanderm/allallblast/data
SLAVE_WORKING_DIR=/state/partition1/sanderm/allallblast/working
SCRIPT_DIR=/home/sanderm/blast
HEAD_WORKING_DIR=/home/sanderm/blast/working_features
BLAST2BLINKSIMPLE=/home/sanderm/bin/blast2BlinkSimple.pl
BLAST2BLINKOVERLAP=/home/sanderm/bin/blast2blink.mjs.pl
PROTEIN_FLAG=F
PARSE_SEQID_FLAG=F
BLAST_EXPECT=1.0e-10
BLAST_OUTPUT_FMT=8
BLAST_PROGRAM=blastn
BLAST_DUST=F
BLAST_STRAND=1
BLAST2BLINK=overlap
OVERLAP_SIGMA=0.51
OVERLAP_PHI=0.51
OVERLAP_MODE=2