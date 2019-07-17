use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';

on develop => sub {
    requires 'A';
    requires 'B';
};
...
$writer->add_prereq('A', '0.01');
$writer->add_prereq('A', '0.02', phase => 'develop');
$writer->add_prereq('B', '0.01', phase => 'develop');
$writer->add_prereq('B', '0.02');
is $writer->src, <<'...';
requires 'A', '0.01';

on develop => sub {
    requires 'A', '0.02';
    requires 'B', '0.01';
};
...

done_testing;
