use strict;
use warnings;

use Test::More;

use Module::CPANfile::Writer;

my $writer = Module::CPANfile::Writer->new(\<<'...');
requires 'A';

on develop => sub {
    requires 'B';
    # comment
};

on build => sub {
};

requires 'C';
...
$writer->add_prereq('B', '0.01');
$writer->add_prereq('D', undef, phase => 'develop');
$writer->add_prereq('A', '0.02', phase => 'develop');
$writer->add_prereq('E', undef, phase => 'build');
$writer->add_prereq('F', undef, phase => 'test');
is $writer->src, <<'...';
requires 'A', '0.01';

on develop => sub {
    requires 'B', '0.01';
    requires 'D';
    # comment
};

on build => sub {
    requires 'E';
};

requires 'C';

on test => sub {
    requires 'F';
};
...

done_testing;
