#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Handlebars;

my $vars = {
    outer => '<em>example</em>',
    elements => [
        { inner => '<em>text</em>' },
        { inner => '<h1>text</h1>' },
    ]
};
my $template = <<EOL;
{{{outer}}}
{{#each elements}}
{{{inner}}}
{{/each}}
EOL
my $expected = <<EOL;
<em>example</em>
<em>text</em>
<h1>text</h1>
EOL

render_ok(
    $template,
    $vars,
    $expected,
    "doy/text-handlebars#6"
);

done_testing;
