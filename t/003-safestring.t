#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Text::Handlebars;
use Text::Xslate 'mark_raw';

my $tx = Text::Handlebars->new;

is(
    $tx->render_string(
        '<h1>{{title}}</h1><p>{{{body}}}</p>',
        { title => 'My New Post', body => 'This is my first post!' },
    ),
    '<h1>My New Post</h1><p>This is my first post!</p>',
);

is(
    $tx->render_string(
        '<h1>{{title}}</h1><p>{{{body}}}</p>',
        { title => 'All About <p> Tags', body => '<i>This is a post about &lt;p&gt; tags</i>' },
    ),
    '<h1>All About &lt;p&gt; Tags</h1><p><i>This is a post about &lt;p&gt; tags</i></p>',
);

is(
    $tx->render_string(
        '<h1>{{title}}</h1><p>{{{body}}}</p>',
        { title => mark_raw('All About &lt;p&gt; Tags'), body => '<i>This is a post about &lt;p&gt; tags</i>' },
    ),
    '<h1>All About &lt;p&gt; Tags</h1><p><i>This is a post about &lt;p&gt; tags</i></p>',
);

done_testing;
