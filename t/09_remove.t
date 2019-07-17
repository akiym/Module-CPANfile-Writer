use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';
requires 'B';

on develop => sub {
    requires 'C';
};
...
$writer->remove_prereq('A');
$writer->remove_prereq('C');
is $writer->src, <<'...';
requires 'B';

on develop => sub {
};
...

done_testing;
