package Text::Handlebars::Symbol;
use Any::Moose;

extends 'Text::Xslate::Symbol';

has is_helper => (
    is  => 'rw',
    isa => 'Bool',
);

has fourth => (
    is => 'rw',
);

has context => (
    is => 'rw',
);

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
