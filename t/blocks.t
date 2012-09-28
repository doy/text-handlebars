#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Text::Handlebars;

my $tx = Text::Handlebars->new;

is(
    $tx->render_string(
        'This is {{#shown}}shown{{/shown}}',
        { shown => 1 },
    ),
    'This is shown',
);

is(
    $tx->render_string(
        'This is {{#shown}}shown{{/shown}}',
        { shown => 0 },
    ),
    'This is ',
);

is(
    $tx->render_string(
        'This is {{#shown}}shown{{/shown}}',
        { shown => [({}) x 3] },
    ),
    'This is shownshownshown',
);

is(
    $tx->render_string(
        'This is {{#shown}}{{content}}{{/shown}}',
        { shown => { content => 'SHOWN' } },
    ),
    'This is SHOWN',
);

is(
    $tx->render_string(
        'This is {{#shown}}{{content}}{{/shown}}',
        {
            shown => [
                { content => '3' },
                { content => '2' },
                { content => '1' },
                { content => 'Shown' },
            ],
        },
    ),
    'This is 321Shown',
);

done_testing;
