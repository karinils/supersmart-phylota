#!/usr/bin/perl -w

# Prints a ci_gi table with any duplicate entries removed...

while (<>)
	{ 
	($ti,$clustid,$cl_type,$gi,$ti_of_gi)=split;
	$key = "$ti\_$clustid\_$cl_type\_$gi";
	if ($seen{$key})
		{
		++$count;
		$tiH{$ti}=1;
		}
	else
		{
		print "$ti\t$clustid\t$cl_type\t$gi\t$ti_of_gi\n";
		$seen{$key}=1;
		}
	}
