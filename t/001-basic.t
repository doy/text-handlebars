use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(syntax => 'Handlebars');

is(
    $tx->render_string(
        'Hello, {{dialect}} world!',
        { dialect => 'Handlebars' },
    ),
    'Hello, Handlebars world!',
);
