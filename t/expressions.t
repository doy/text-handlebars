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

render_ok(
    '<h1>{{page.article.title}}</h1> - {{date}}',
    {
        page => {
            article => { title => 'Multilevel field access' },
        },
        date => '2012-10-01',
    },
    '<h1>Multilevel field access</h1> - 2012-10-01',
    "multilevel field access with ."
);

render_ok(
    '{{#article}}<h1>{{title}}</h1> - {{../date}}{{/article}}',
    { article => { title => 'Backtracking' }, date => '2012-10-01' },
    '<h1>Backtracking</h1> - 2012-10-01',
    "backtracking with ../"
);

{ local $TODO = "autochomping issues";
render_ok(
    <<'TEMPLATE',
{{#page}}
{{#article}}<h1>{{title}}</h1> - {{../../date}}{{/article}}
{{/page}}
TEMPLATE
    {
        page => {
            article => { title => 'Multilevel Backtracking' },
        },
        date => '2012-10-01',
    },
    <<'RENDERED',
<h1>Multilevel Backtracking</h1> - 2012-10-01
RENDERED
    "multilevel backtracking with ../"
);
}

render_ok(
    '{{#article}}<h1>{{title}}</h1> - {{../metadata.date}}{{/article}}',
    {
        article  => { title => 'Backtracking' },
        metadata => { date  => '2012-10-01' },
    },
    '<h1>Backtracking</h1> - 2012-10-01',
    "backtracking into other hash variables with ../ and ."
);

done_testing;
