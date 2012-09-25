use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(syntax => 'Handlebars');

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
        { title => 'All about <p> Tags', body => '<i>This is a post about &lt;p&gt; tags</i>' },
    ),
    '<h1>All About &lt;p&gt; Tags</h1><p><i>This is a post about &lt;p&gt; tags</i></p>',
);

# XXX I'm not sure what the safestring constructor should be called
# it's effectively Handlebars::SafeString->new($str) in JS
is(
    $tx->render_string(
        '<h1>{{title}}</h1><p>{{{body}}}</p>',
        { title => Handlebars::SafeString->new('All about &lt;p&gt; Tags'), body => '<i>This is a post about &lt;p&gt; tags</i>' },
    ),
    '<h1>All About &lt;p&gt; Tags</h1><p><i>This is a post about &lt;p&gt; tags</i></p>',
);
