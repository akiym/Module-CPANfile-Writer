package Module::CPANfile::Writer;
use strict;
use warnings;
use Carp qw/croak/;

use Babble::Match;
use PPR;

our $VERSION = "0.01";

my $re_cpanfile_prereq = '(?:requires|recommends|suggests|conflicts)';

sub new {
    my ($class, $f) = @_;
    croak('Usage: Module::CPANfile::Writer->new($f)') unless defined $f;

    my $src;
    if (ref $f) {
        croak('Not a SCALAR reference') unless ref $f eq 'SCALAR';

        $src = $$f;
    } else {
        $src = do {
            open my $fh, '<', $f or die $!;
            local $/; <$fh>;
        };
    }

    return bless {
        src            => $src,
        add_prereqs    => [],
        remove_prereqs => [],
    }, $class;
}

sub save {
    my ($self, $file) = @_;
    croak('Usage: $self->save($file)') unless defined $file;

    open my $fh, '>', $file or die $!;
    print {$fh} $self->src;
}

sub add_prereq {
    my ($self, $module, $version, %opts) = @_;
    croak('Usage: $self->add_prereq($module, [$version, %opts])') unless defined $module;

    my $phase = $opts{phase} || 'runtime';
    my $relationship = $opts{relationship} || 'requires';

    push @{$self->{add_prereqs}}, {
        module       => $module,
        version      => $version,
        phase        => $phase,
        relationship => $relationship,
    };
}

sub remove_prereq {
    my ($self, $module, %opts) = @_;
    croak('Usage: $self->remove_prereq($module, [%opts])') unless defined $module;

    my $phase = $opts{phase} || 'runtime';
    my $relationship = $opts{relationship} || 'requires';

    push @{$self->{remove_prereqs}}, {
        module       => $module,
        phase        => $phase,
        relationship => $relationship,
    };
}

sub src {
    my $self = shift;

    my $top = Babble::Match->new(top_rule => 'Document', text => $self->{src});

    $top->each_match_within('Call' => [
        'on (?&PerlOWS)',
        [ phase => '(?: (?&PerlString) | (?&PerlBareword) )' ],
    ] => sub {
        my ($m) = @_;
        my $phase = _perl_string_or_bareword($m->submatches->{phase}->text);

        $self->_add_prereqs($m, $phase);
        $self->_remove_prereqs($m, $phase);
    });

    $self->_add_prereqs($top, 'runtime');
    $self->_remove_prereqs($top, 'runtime');

    return $top->text;
}

sub _add_prereqs {
    my ($self, $m, $phase) = @_;

    return unless @{$self->{add_prereqs}};

    $m->each_match_within('Call' => [
        # TODO: support configure_requires, build_requires, test_requires, author_requires
        [ relationship => $re_cpanfile_prereq ],
        '(?&PerlOWS) \(? (?&PerlOWS)',
        [ module => '(?: (?&PerlString) | (?&PerlBareword) )' ],
        [ arg1_before => '(?&PerlOWS) (?: (?>(?&PerlComma)) (?&PerlOWS) )*' ],
        [ arg1 => '(?&PerlAssignment)?' ],
        '(?&PerlOWS) (?: (?>(?&PerlComma)) (?&PerlOWS) )*',
        [ args => '(?&PerlCommaList)?' ],
        '\)? (?&PerlOWS)',
    ] => sub {
        my ($m) = @_;
        my $relationship = $m->submatches->{relationship}->text;
        my $module = _perl_string_or_bareword($m->submatches->{module}->text);

        my $prereq = _find_prereq($self->{add_prereqs}, $module, $phase, $relationship) or return;

        my $version = $prereq->{version};
        if ($m->submatches->{arg1}->text eq '' ||            # no arguments except module name
            _args_num($m->submatches->{args}->text) % 2 == 1 # not specify module version but there are options
        ) {
            # requires 'A';
            # requires 'B', dist => '...';
            if ($version) {
                $m->submatches->{module}->transform_text(sub {s/$/, '$version'/});
            }
        } else {
            # requires 'C', '0.01';
            if ($version) {
                $m->submatches->{arg1}->replace_text(qq{'$version'});
            } else {
                $m->submatches->{arg1}->replace_text('');
                $m->submatches->{arg1_before}->replace_text('');
            }
        }
    });
}

sub _remove_prereqs {
    my ($self, $m, $phase) = @_;

    return unless @{$self->{remove_prereqs}};

    $m->each_match_within('Call' => [
        [ relationship => $re_cpanfile_prereq ],
        '(?&PerlOWS) \(? (?&PerlOWS)',
        [ module => '(?&PerlString)' ],
    ] => sub {
        my ($m) = @_;
        my $relationship = $m->submatches->{relationship}->text;
        my $module = _perl_string_or_bareword($m->submatches->{module}->text);

        _find_prereq($self->{remove_prereqs}, $module, $phase, $relationship) or return;

        $m->replace_text('');
    })
}

sub _end_of_prereq {
    my ($self, $m) = @_;

}

sub _find_prereq {
    my ($prereqs, $module, $phase, $relationship) = @_;

    for my $prereq (@$prereqs) {
        if ($prereq->{module} eq $module && $prereq->{phase} eq $phase && $prereq->{relationship} eq $relationship) {
            return $prereq;
        }
    }

    return undef;
}

sub _perl_string_or_bareword {
    my ($s) = @_;

    if ($s =~ /\A (?&PerlString) \Z $PPR::GRAMMAR/x) {
        return eval $s;
    }

    # bareword
    return $s;
}

sub _args_num {
    my ($s) = @_;

    # count number of arguments from PerlCommaList
    return scalar grep defined, $s =~ m{
        \G (?: (?>(?&PerlComma)) (?&PerlOWS) )* ((?&PerlAssignment))
        $PPR::GRAMMAR
    }gcx;
}

1;
__END__

=encoding utf-8

=head1 NAME

Module::CPANfile::Writer - Module for modifying the cpanfile

=head1 SYNOPSIS

    use Module::CPANfile::Writer;

    my $writer = Module::CPANfile::Writer->new('cpanfile');
    $writer->add_prereq('Moo', '2.003004');
    $writer->add_prereq('Test2::Suite', undef, phase => 'test', relationship => 'recommends');
    $writer->remove_prereq('Moose');
    $writer->save('cpanfile');

=head1 DESCRIPTION

Module::CPANfile::Writer lets you modify the version of modules in the existing cpanfile.

cpanfile is very flexible bacause it is written in Perl by using DSL, you can write comments and even code.
Therefore, modifying the cpanfile is not easy and you have to understand Perl code.

The idea of modifying the cpanfile was inspired by L<App::CpanfileSliptop>.
This module uses L<PPI> to parse and analyze the cpanfile as Perl code.
But PPI depends XS modules such as L<Clone> and L<Params::Util>, so these modules are annoying to fatpack in one pure-perl script.

Module::CPANfile::Writer has no XS modules in dependencies because it uses L<Babble> and L<PPR> to parse (recognize) Perl code.

=head1 METHODS

=over 4

=item $writer = Module::CPANfile::Writer->new($file)

=item $writer = Module::CPANfile::Writer->new(\$src)

This will create a new instance of L<Module::CPANfile::Writer>.

It takes the filename or the content of cpanfile as scalarref.

=item $writer->add_prereq($module, [$version, phase => $phase, relationship => $relationship)

Add/modify the version of specified C<$module> in cpanfile.

You can also pass C<$version> to 0 or undef, this will remove the version requirement of C<$module>.

=item $writer->remove_prereq($module, [phase => $phase, relationship => $relationship])

Remove specified C<$module> in cpanfile.

=item $writer->save($file);

Write the content of modified cpanfile to the C<$file>.

=item $writer->src

This will returns the content of modified cpanfile.

=back

=head1 SEE ALSO

L<Module::CPANfile>

=head1 LICENSE

Copyright (C) Takumi Akiyama.
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.



Takumi Akiyama E<lt>t.akiym@gmail.comE<gt>

=cut

