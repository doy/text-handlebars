#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Text::Handlebars;

my $tx = Text::Handlebars->new;

is(
    $tx->render_string(
        '<h1>{{title}}</h1>',
        { title => 'Xslate rocks' },
    ),
    '<h1>Xslate rocks</h1>',
);

is(
    $tx->render_string(
        '<h1>{{article.title}}</h1>',
        { article => { title => 'Hash references rock' } },
    ),
    '<h1>Hash references rock</h1>',
);

is(
    $tx->render_string(
        '<h1>{{article/title}}</h1>',
        { article => { title => 'Deprecated syntax does not' } },
    ),
    '<h1>Deprecated syntax does not</h1>',
);

done_testing;
