#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Handlebars;

render_ok(
    'This is {{#shown}}shown{{/shown}}',
    { shown => 1 },
    'This is shown',
    "true block variable"
);

render_ok(
    'This is {{#shown}}shown{{/shown}}',
    { shown => 0 },
    'This is ',
    "false block variable"
);

render_ok(
    'This is {{#shown}}shown{{/shown}}',
    { shown => [({}) x 3] },
    'This is shownshownshown',
    "array block variable"
);

render_ok(
    'This is {{#shown}}{{content}}{{/shown}}',
    { shown => { content => 'SHOWN' } },
    'This is SHOWN',
    "nested hash block variable"
);

render_ok(
    'This is {{#shown}}{{content}}{{/shown}}',
    {
        shown => [
            { content => '3' },
            { content => '2' },
            { content => '1' },
            { content => 'Shown' },
        ],
    },
    'This is 321Shown',
    "nested array of hashes block variable"
);

done_testing;
