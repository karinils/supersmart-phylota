#!/usr/bin/perl

@files = </var/www/html/pb/alignments/clustal/*>;

# Note that you better have user or group write access permission to this directory and all its files!

for $oldfile (@files)
	{
	$newfile=$oldfile;
	$newfile =~ s/r(\d+)\_//;
	rename $oldfile, $newfile;
	$H{$newfile}=1;
	}
