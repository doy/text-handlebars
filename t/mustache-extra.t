#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Text::Handlebars;

render_ok(
    <<'TEMPLATE',
* {{name}}
* {{age}}
* {{company}}
* {{& company}}
TEMPLATE
    {
        name    => 'Chris',
        company => '<b>GitHub</b>',
    },
    <<'RENDERED',
* Chris
* 
* &lt;b&gt;GitHub&lt;/b&gt;
* <b>GitHub</b>
RENDERED
    "& for make_raw"
);

sub render_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return _render_ok('render_string', @_);
}

sub render_file_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return _render_ok('render', @_);
}

sub _render_ok {
    my $render_method = shift;
    my $opts = ref($_[0]) && ref($_[0]) eq 'HASH' ? shift : {};
    my ($template, $env, $expected, $desc) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $tx = Text::Handlebars->new(%$opts);

    my $exception = exception {
        is($tx->$render_method($template, $env), $expected, $desc);
    };
    fail("$desc (threw an exception)") if $exception;
    is(
        $exception,
        undef,
        "no exceptions for $desc"
    );
}

done_testing;
