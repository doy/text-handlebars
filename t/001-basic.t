#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Text::Handlebars;

my $tx = Text::Handlebars->new;

is(
    $tx->render_string(
        'Hello, {{dialect}} world!',
        { dialect => 'Handlebars' },
    ),
    'Hello, Handlebars world!',
);

done_testing;
