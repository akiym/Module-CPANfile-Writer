use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';

on test => sub {
    requires 'B';
    # comment
};

requires 'C';
# comment
...
$writer->add_prereq('D', '0.01');
$writer->add_prereq('E', '0', relationship => 'recommends');
$writer->add_prereq('F', '0', phase => 'test');
is $writer->src, <<'...';
requires 'A';

on test => sub {
    requires 'B';
    requires 'F';
    # comment
};

requires 'C';
requires 'D', '0.01';
recommends 'E';
# comment
...

done_testing;
