#!/usr/bin/perl

$cmd = "ls -1t /home/sanderm/blast/SGE_JOBS";
@files= `$cmd`;

for $filename (@files)
	{
	chomp $filename;
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/home/sanderm/blast/SGE_JOBS/$filename");
	($jobid)=($filename=~/o(\d+)/);
	($logfile) = </home/sanderm/blast/working_crawl/*logfile.id$jobid>;

	#print "$jobid\t$logfile\n";

	open FH, "<$logfile";

	while (<FH>)
		{
		chomp;
		($key,$value) = split /  :  /;
		$H{$key}=$value;
		}
	close FH;
	print "$H{'Root node of run'}\t$jobid\t$logfile\t$size\t$H{HOSTNAME}\t$H{'Run date/time'}\n" if ($size > 50);

	}


