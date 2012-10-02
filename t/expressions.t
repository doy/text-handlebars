#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Handlebars;

render_ok(
    '<h1>{{title}}</h1>',
    { title => 'Xslate rocks' },
    '<h1>Xslate rocks</h1>',
    "basic variables"
);

render_ok(
    '<h1>{{article.title}}</h1>',
    { article => { title => 'Hash references rock' } },
    '<h1>Hash references rock</h1>',
    ". separator"
);

render_ok(
    '<h1>{{article/title}}</h1>',
    { article => { title => 'Deprecated syntax does not' } },
    '<h1>Deprecated syntax does not</h1>',
    "/ separator"
);

done_testing;
