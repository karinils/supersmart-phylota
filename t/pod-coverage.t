# this is a unit test
#!/usr/bin/perl
use strict;
use warnings;
# this is a unit test
use Test::More;
eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
all_pod_coverage_ok();

