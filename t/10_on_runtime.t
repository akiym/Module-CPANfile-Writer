use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
on runtime => sub {
    requires 'A';
};
...
$writer->add_prereq('B');
is $writer->src, <<'...';
on runtime => sub {
    requires 'A';
    requires 'B';
};
...

done_testing;
