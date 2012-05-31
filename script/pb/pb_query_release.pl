#!/usr/bin/perl -w
use pb;
while ( $fl = shift @ARGV ) {
    $par = shift @ARGV;
    if ( $fl =~ /-c/ ) { $configFile = $par; }
}
%pbH     = %{ pb::parseConfig($configFile) };
$release = pb::currentGBRelease();
print
"The current release setting based on the config file $configFile is $release\n";
