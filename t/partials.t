#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Handlebars;

{ local $TODO = "unimplemented";
render_ok(
    {
        path => [ { dude => '{{#this}}{{name}} ({{url}}) {{/this}}' } ],
    },
    'Dudes: {{>dude dudes}}',
    {
        dudes => [
            { name => "Yehuda", url => "http://yehuda" },
            { name => "Alan",   url => "http://alan" },
        ],
    },
    'Dudes: Yehuda (http://yehuda) Alan (http://alan) ',
    "passing a context to partials"
);
}

render_ok(
    {
        path => [ { dude => '{{name}}' } ],
    },
    'Dudes: {{> [dude]}}',
    {
        name         => 'Jeepers',
        another_dude => 'Creepers',
    },
    'Dudes: Jeepers',
    "using literals for partials"
);

done_testing;
