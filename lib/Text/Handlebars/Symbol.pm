package Text::Handlebars::Symbol;
use Any::Moose;

extends 'Text::Xslate::Symbol';

has is_helper => (
    is  => 'rw',
    isa => 'Bool',
);

has is_block_helper => (
    is  => 'rw',
    isa => 'Bool',
);

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
