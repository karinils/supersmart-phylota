drop table if exists ci_gi;
create table if not exists ci_gi(
	ti INT UNSIGNED,
	clustid INT UNSIGNED,
	cl_type ENUM('node','subtree'),
	gi BIGINT UNSIGNED,
	ti_of_gi INT UNSIGNED, 
	index(cl_type),
	index(cl_type),
	index(gi),
	index(ti,clustid,cl_type)
);

drop table if exists nodes;
create table if not exists nodes(
    ti INT UNSIGNED primary key,
    ti_anc INT UNSIGNED, 
    INDEX(ti_anc), 
    terminal_flag BOOL, # if '1', node is a tip
    rank_flag BOOL, 
    model BOOL,
    taxon_name VARCHAR(128),
    common_name VARCHAR(128),
    rank varchar(64),
    n_gi_node INT UNSIGNED, 
    n_gi_sub_nonmodel INT UNSIGNED,
    n_gi_sub_model INT UNSIGNED,
    n_clust_node INT UNSIGNED, 
    n_clust_sub INT UNSIGNED, 
    n_PIclust_sub INT UNSIGNED, 
    n_sp_desc INT UNSIGNED,
    n_sp_model INT UNSIGNED,
    n_leaf_desc INT UNSIGNED,
    n_otu_desc INT UNSIGNED   
);

drop table if exists clusters;
create table if not exists clusters(
	ti_root INT UNSIGNED,
	ci INT UNSIGNED, 
	cl_type ENUM('node','subtree'),
	INDEX(ti_root,ci,cl_type), 
	n_gi INT UNSIGNED, 
	n_ti INT UNSIGNED, 
	PI BOOL,		# if its phylogenically informative
	MinLength INT UNSIGNED,
	MaxLength INT UNSIGNED,
	MaxAlignDens FLOAT,
	ci_anc INT UNSIGNED,
	seed_gi BIGINT UNSIGNED,
	Q FLOAT,
	TC FLOAT,
	clustalw_tree LONGTEXT,
	muscle_tree LONGTEXT,
	strict_tree LONGTEXT,
	clustalw_res FLOAT,
	muscle_res FLOAT,
	strict_res FLOAT,
	ortho TINYINT 		# 1 = orthologous cluster
);

drop table if summary_stats;
create table if not exists summary_stats (
	gb_release INT UNSIGNED,    # genbank release number
	gb_rel_date VARCHAR(25),    # genbank release date
	n_gis INT UNSIGNED,         # number of GIs in seq table
	n_nodes INT UNSIGNED,       # number of node in nodes table
	n_nodes_term INT UNSIGNED,  # number of tips in nodes table
	n_clusts_node INT UNSIGNED,
	n_clusts_sub  INT UNSIGNED,
	n_nodes_with_sequence  INT UNSIGNED,
	n_clusts INT UNSIGNED,
	n_PI_clusts INT UNSIGNED,
	n_singleton_clusts INT UNSIGNED,
	n_large_gi_clusts INT UNSIGNED,
	n_large_ti_clusts INT UNSIGNED,
	n_largest_gi_clust INT UNSIGNED,
	n_largest_ti_clust INT UNSIGNED
);
