#!/usr/bin/perl

$index=0;
while(<>)
	{
	($ti_root,$ci,$cl_type,$seq_id,$ti,$data_type)=split;
	$key = "$ti_root\_$ci\_$cl_type\_$data_type";
	if (!exists $h{$key})
		{
		$h{$key}=++$index;	
		}

	print "$h{$key}\t$seq_id\t$ti\n";
	}	

