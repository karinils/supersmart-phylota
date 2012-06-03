# this is an object oriented perl module
package pb;


# Version. 0.10

sub parseConfig
{
my ($file)=$_[0];
my ($key,$val,@words);
open FH, "<$file";
while (<FH>)
	{
	chomp;
	next if (/^#/ || /^$/); # skip blank lines or lines starting with a comment character
	@words = split /#/; # after this, the first element will be non-commented stuff
	if ($words[0] =~ /=/)
		{
		($key,$val)=split /=/, $words[0];
		$key=~s/\s+//g;	# get rid of white space
		$val=~s/\s+//g;
		$phylotaH{$key}=$val;
		}
	}
close FH;
return \%phylotaH;
}

sub currentGBRelease
{
# Note: should change this to read the phylotaH ref passed, rather than use a global...
open FH,"<$phylotaH{GB_RELNUM_FILE}"; # relies on the persistence of this global
$release=<FH>;
chomp $release;
close FH;
return $release;
}
sub currentGBReleaseDate
{
# Note: should change this to read the phylotaH ref passed, rather than use a global...
open FH,"<$phylotaH{GB_RELNUM_DATE_FILE}"; # relies on the persistence of this global
$release_date=<FH>;
chomp $release_date;
close FH;
return $release_date;
}



1;
