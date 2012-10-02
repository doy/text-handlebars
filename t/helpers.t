use strict;
use warnings;
use Test::More;
use Text::Xslate;

plan skip_all => "unimplemented";

my $tx = Text::Xslate->new(syntax => 'Handlebars');

# XXX I'm not sure how helpers should be registered in Perl
# in JS, it's global which is crappy
# Text::Xslate->new has a "function" parameter for registering helpers
Handlebars->registerHelper(noop => sub {
    my ($context, $options) = @_;
    return $options->{fn}->($context);
});

is(
    $tx->render_string(
        '<h1>{{title}}</h1><p>{{#noop}}{{body}}{{/noop}}</p>',
        { title => 'A', body => 'the first letter' },
    ),
    '<h1>A</h1><p>the first letter</p>',
);

Handlebars->registerHelper(list => sub {
    my ($items, $options) = @_;
    my $out = "<ul>";

    for my $item (@$items) {
        $out .= "<li>" . $options->{fn}->($item) . "</li>";
    }

    return $out . "</ul>";
});

is(
    $tx->render_string(
        '{{#list people}}{{firstName}} {{lastName}}{{/list}}',
        { people => [
            { firstName => 'Jesse',  lastName => 'Luehrs' },
            { firstName => 'Shawn',  lastName => 'Moore' },
            { firstName => 'Stevan', lastName => 'Little' },
        ] },
    ),
    '<ul><li>Jesse Luehrs</li><li>Shawn Moore</li><li>Stevan Little</li></ul>',
);

done_testing;
