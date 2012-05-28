DOWNLOADING THE ENTIRE DATABASE OR ASSOCIATED SCRIPTS

Current and previous releases of the PhyLoTA Browser database can be downloaded
in a format suitable for rebuilding it locally in a mysql database (or the
equivalent). The database is exported as a set of mysql commands using the
'mysqldump' utility. The file is named in the following format: 

pb.bu.rel###.date.gz 

where rel### is the GenBank release upon which the database was built, and date
is the date the database was exported. This very large file is then broken into
several 250 MB pieces with file names as above, but with the suffix, 'partxx'
replacing the .gz. These can be downloaded separately. To join them again under
Unix/Linux the command would be (for example): 

cat pb.bu.rel168.8.18.2009.part* > pb.bu.rel168.8.18.2009.gz 

Once the file is uncompressed it can be imported into mysql directly. The files
are plain text, so they can also be parsed by other software easily. 

Go to the download directory:
http://phylota.net/pb/Download
