create table if not exists inparanoid(
	id int(10) unsigned not null,
	guid int(10) unsigned not null,
	filename varchar(64) default null,
	confidence float default NULL,
	protid varchar(64) default null,
	index(protid),
	bootstrap int(10)
) ENGINE=INNODB;