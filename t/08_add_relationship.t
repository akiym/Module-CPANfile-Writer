use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';
...
$writer->add_prereq('A', '0.01', relationship => 'conflicts');
$writer->add_prereq('B', undef, relationship => 'recommends');
is $writer->src, <<'...';
requires 'A';
conflicts 'A', '0.01';
recommends 'B';
...

done_testing;
