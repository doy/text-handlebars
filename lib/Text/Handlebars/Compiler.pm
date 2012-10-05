package Text::Handlebars::Compiler;
use Any::Moose;

extends 'Text::Xslate::Compiler';

use Try::Tiny;

has '+syntax' => (
    default => 'Handlebars',
);

sub define_helper { shift->parser->define_helper(@_) }

sub _generate_block {
    my $self = shift;
    my ($node) = @_;

    my @compiled = map { $self->compile_ast($_) } @{ $node->second };

    unshift @compiled, $self->_localize_vars($node->first)
        if $node->first;

    return @compiled;
}

sub _generate_include {
    my $self = shift;
    my ($node) = @_;

    my $file = $node->first;
    $file->id($file->id . $self->engine->{suffix})
        unless try { $self->engine->find_file($file->id); 1 };
    return $self->SUPER::_generate_include($node);
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
