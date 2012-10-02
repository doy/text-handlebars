#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Handlebars;

{ local $TODO = "unimplemented"; local $SIG{__WARN__} = sub { };
render_ok(
    {
        helpers => {
            noop => sub {
                my ($context, $options) = @_;
                return $options->{fn}->($context);
            },
        },
    },
    '<h1>{{title}}</h1><p>{{#noop}}{{body}}{{/noop}}</p>',
    { title => 'A', body => 'the first letter' },
    '<h1>A</h1><p>the first letter</p>',
    "noop helper"
);

render_ok(
    {
        helpers => {
            list => sub {
                my ($items, $options) = @_;
                my $out = "<ul>";

                for my $item (@$items) {
                    $out .= "<li>" . $options->{fn}->($item) . "</li>";
                }

                return $out . "</ul>";
            },
        },
    },
    '{{#list people}}{{firstName}} {{lastName}}{{/list}}',
    { people => [
        { firstName => 'Jesse',  lastName => 'Luehrs' },
        { firstName => 'Shawn',  lastName => 'Moore' },
        { firstName => 'Stevan', lastName => 'Little' },
    ] },
    '<ul><li>Jesse Luehrs</li><li>Shawn Moore</li><li>Stevan Little</li></ul>',
    "helpers with arguments"
);
}

done_testing;
