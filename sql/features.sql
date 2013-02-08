create table if not exists features(
	feature_id  bigint(20) not null auto_increment,
	primary_tag varchar(12),
	gi bigint(20),
	gi_feat bigint(20),
	ti bigint(20),
	acc varchar(12),
	acc_vers smallint(5),
	length bigint(20),
	codon_start tinyint(3),
	transl_table tinyint(3),
	gene varchar(20),
	product text,
	seq mediumtext,
	primary key(feature_id),
	key(gi),
	key(ti),
	key(gene)
) ENGINE=MyISAM;
