use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';
requires 'B';
...
$writer->remove_prereq('A');
is $writer->src, <<'...';
requires 'B';
...

done_testing;
