-- this is a SQL script file
-- drop database phylota;
-- create database phylota;

-- table for nodes in the NCBI taxonomy. Each node is a taxon, with an
-- identifier (ti), and a self-joining foreign key for its ancestor. Some
-- nodes are terminal (i.e. tips), some are flagged as belonging to a 'model
-- organism', for which there is a wealth of sequence data. Nodes have
-- scientific names for their rank (e.g. rank=genus taxon_name=Homo) and
-- possibly a common name.
-- drop table if exists nodes;
create table if not exists nodes(
	ti int(10) unsigned not null primary key, -- taxon ID
	ti_anc int(10) unsigned default null,     -- parent ID
	index(ti_anc), 
	terminal_flag tinyint(1) default null,    -- if '1', node is a tip
	rank_flag tinyint(1) default null,        -- ???
	model tinyint(1) default null,            -- a 'model' organism has very many sequences
	taxon_name varchar(128) default null,     -- scientific name
	common_name varchar(128) default null,    -- common name
	rank varchar(64) default null,            -- taxonomic rank
	n_gi_node int(10) unsigned default null,         -- number of GIs at that node?
	n_gi_sub_nonmodel int(10) unsigned default null, -- number of non-model org GIs subtended?
	n_gi_sub_model int(10) unsigned default null,    -- number of model org GIs subtended?
	n_clust_node int(10) unsigned default null,      -- number of clusters for node
	n_clust_sub int(10) unsigned default null,       -- number of clusters subtended
	n_PIclust_sub int(10) unsigned default null,  -- "phylogenically informative" [sic] clusters 
	n_sp_desc int(10) unsigned default null,      -- number of descendant species?
	n_sp_model int(10) unsigned default null,     -- number of model organisms?
	n_leaf_desc int(10) unsigned default null,    -- number of leaf descendants?
	n_otu_desc int(10) unsigned default null      -- number of operational taxonomic units?
	ti_genus int(10) unsigned DEFAULT NULL,
	n_genera int(10) unsigned DEFAULT NULL
) ENGINE=INNODB;

-- drop table if exists clusters;
create table if not exists clusters(
	ti_root int(10) unsigned default NULL, -- taxon ID of the cluster root
	index(ti_root),
	foreign key (ti_root) references nodes(ti),
	
	ci int(10) unsigned primary key,      -- cluster id (primary key?)
	
	cl_type enum('node','subtree') default NULL, -- cluster type
	index(ti_root,ci,cl_type), 
	n_gi int(10) unsigned default NULL,              -- number of GIs
	n_ti int(10) unsigned default NULL,              -- number of TIs
	PI tinyint(1) default NULL,		                 -- if its phylogenically informative
	MinLength int(10) unsigned default NULL,         -- min length of seqs in cluster?
	MaxLength int(10) unsigned default NULL,         -- max...?
	MaxAlignDens float default NULL,                 -- alignment density, maybe % overlap?
	ci_anc int(10) unsigned default NULL,            -- cluster id of the ancestor cluster
	seed_gi bigint(20) unsigned default NULL,        -- backbone sequence
	Q float default NULL,                            -- ???
	TC float default NULL,                           -- ???
	clustalw_tree longtext, -- newick string
	muscle_tree longtext,   -- newick string
	strict_tree longtext,   -- newick string
	clustalw_res float default NULL,
	muscle_res float default NULL,
	strict_res float default NULL,
	ortho tinyint(4) default NULL, 		-- 1 = orthologous cluster
	n_gen int(10) unsigned default NULL,
	n_child int(10) unsigned default NULL
) ENGINE=INNODB;

-- table for sequences from genbank. sequences have an identifier (gi),
-- and belong to a taxon (ti). length is sequence length, def is FASTA
-- def line, seq is raw sequence data, or NULL for sequences that are
-- too long. we seem to track the genbank release number and date in here.
-- not sure what mol_type and division are for.
-- drop table if exists seqs;
create table if not exists seqs (
	gi bigint(20) unsigned not null default '0' primary key, -- Sequence ID, checked (primary key)
	
	ti bigint(20) unsigned default null, -- Taxon ID, checked (foreign key)
	index(ti),
	foreign key (ti) references nodes(ti),
	
	acc varchar(12) default null, -- accession number
	index(acc),
	acc_vers smallint(5) unsigned default null, -- accession version number
	
	length bigint(20) unsigned default null,  -- sequence length, checked
	division varchar(5) default null,         -- ??
	acc_date date default null,               -- accession date
	gbrel smallint(5) unsigned default null,  -- genbank release number
	def text,                                 -- FASTA def line
	seq mediumtext                            -- Raw sequence
) ENGINE=INNODB;

-- intersection table between clusters and seqs? and taxa?
-- drop table if exists ci_gi;
create table if not exists ci_gi (
	ti int(10) unsigned DEFAULT NULL,
	index(ti),
	foreign key (ti) references nodes(ti),
	
	clustid int(10) unsigned DEFAULT NULL,
	index(clustid),
	foreign key (clustid) references clusters(ci),
	
	cl_type enum('node','subtree') DEFAULT NULL,
	
	gi bigint(20) unsigned DEFAULT NULL,
	index(gi),
	foreign key (gi) references seqs(gi),  
	
	ti_of_gi int(10) unsigned DEFAULT NULL,
	KEY cl_type (cl_type)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- table for summary statistics of a phylota run
-- drop table if exists summary_stats;
create table if not exists summary_stats (
	gb_release int(10) unsigned DEFAULT NULL,    -- genbank release number
	gb_rel_date varchar(25) DEFAULT NULL,        -- genbank release date
	n_gis int(10) unsigned DEFAULT NULL,         -- number of GIs in seq table
	n_nodes int(10) unsigned DEFAULT NULL,       -- number of node in nodes table
	n_nodes_term int(10) unsigned DEFAULT NULL,  -- number of tips in nodes table
	n_clusts_node int(10) unsigned DEFAULT NULL,
	n_clusts_sub int(10) unsigned DEFAULT NULL,
	n_nodes_with_sequence int(10) unsigned DEFAULT NULL,
	n_clusts int(10) unsigned DEFAULT NULL,
	n_PI_clusts int(10) unsigned DEFAULT NULL,
	n_singleton_clusts int(10) unsigned DEFAULT NULL,
	n_large_gi_clusts int(10) unsigned DEFAULT NULL,
	n_large_ti_clusts int(10) unsigned DEFAULT NULL,
	n_largest_gi_clust int(10) unsigned DEFAULT NULL,
	n_largest_ti_clust int(10) unsigned DEFAULT NULL,
	alignments_done tinyint(1) DEFAULT NULL,
	trees_done tinyint(1) DEFAULT NULL	
) ENGINE=INNODB;
