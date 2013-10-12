package Dist::Zilla::Plugin::Test::CheckDeps;
# vim: set ts=4 sw=4 tw=78 et nolist :

use Moose;
extends qw/Dist::Zilla::Plugin::InlineFiles/;
with qw/Dist::Zilla::Role::TextTemplate Dist::Zilla::Role::PrereqSource/;
use namespace::autoclean;

has todo_when => (
    is => 'ro',
    isa => 'Str',
    default => '0',     # special value for 'insert no special code at all'
);

has fatal => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has level => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => 'classic',
);

has filename => (
    is => 'ro',
    isa => 'Str',
    default => 't/00-check-deps.t',
);

around add_file => sub {
    my ($orig, $self, $file) = @_;

    return $self->$orig(
        Dist::Zilla::File::InMemory->new(
            name    => $self->filename,
            content => $self->fill_in_string($file->content,
            {
                dist => \($self->zilla),
                plugin => \$self,
                todo_when => $self->todo_when,
                fatal => $self->fatal,
                level => $self->level,
            })
        )
    );
};

sub register_prereqs {
    my $self = shift;
    $self->zilla->register_prereqs({ phase => 'test' }, 'Test::More' => '0.94', 'Test::CheckDeps' => '0.010');
}

__PACKAGE__->meta->make_immutable;

# ABSTRACT: Check for presence of dependencies

=pod

=head1 SYNOPSIS

 [Test::CheckDeps]
 fatal = 0          ; default
 level = classic

=head1 DESCRIPTION

This module adds a test that assures all dependencies have been installed properly. If requested, it can bail out all testing on error.

This plugin accepts the following options:

=over 4

=item * C<todo_when>: a code string snippet (evaluated when the test is run)
to indicate when failing tests should be considered TODO, rather than genuine
fails -- default is '0' (tests are never TODO).

Other suggested values are:

    todo_when = !$ENV{AUTHOR_TESTING} && !$ENV{AUTOMATED_TESTING}
    todo_when = $^V < '5.012'   ; CPAN.pm didn't reliably read META.* before this

=item * C<fatal>: if true, C<BAIL_OUT> is called if the tests fail. Defaults
to false.

=item * C<level>: passed to C<check_dependencies> in L<Test::CheckDeps>.
(Defaults to C<classic>.)

=item * C<filename>: the name of the generated file. Defaults to
F<t/00-check-deps.t>.

=back

=for Pod::Coverage register_prereqs

=cut

__DATA__
___[ test-checkdeps ]___
use strict;
use warnings;

# this test was generated with {{ ref($plugin) . ' ' . ($plugin->VERSION || '<self>') }}

use Test::More 0.94;
{{
    my $use = 'use Test::CheckDeps 0.010;';

    # todo_when = 0 is treated as a special default, backwards-compatible case
    $use = "BEGIN {\n    ($todo_when) && eval \"" . $use
        . " 1\"\n        or plan skip_all => '!!! Test::CheckDeps required for checking dependencies -- failure to satisfy specified prerequisites!';\n}\n"
        . $use
            if $todo_when ne '0';
    $use
}}

{{
    $todo_when eq '0'
        ? ''
        : "TODO: {\n"
            . "local \$TODO = 'these tests are not fatal when $todo_when' if (${todo_when});\n";
}}
check_dependencies('{{ $level }}');
{{
    $todo_when ne '0' ? "}\n" : '';
}}

if ({{ $fatal }}) {
    BAIL_OUT("Missing dependencies") if !Test::More->builder->is_passing;
}

done_testing;
