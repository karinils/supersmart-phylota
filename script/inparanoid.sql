create table if not exists inpara(
	id int(10) unsigned not null,
	guid int(10) unsigned not null,
	filename varchar(64) default null,
	confidence float default null,
	protid varchar(64) default null,
	key(protid),
	bootstrap varchar(4)
) ENGINE=MyISAM;