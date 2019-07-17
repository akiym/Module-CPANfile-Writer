use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';
requires 'B';

requires 'C';
# comment
...
$writer->add_prereq('D', undef);
is $writer->src, <<'...';
requires 'A';
requires 'B';

requires 'C';
requires 'D', '0.01';
# comment
...

done_testing;
