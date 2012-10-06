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

sub _generate_key {
    my $self = shift;
    my ($node) = @_;

    my $var = $node->clone(arity => 'variable');

    return $self->compile_ast($self->_check_lambda($var));
}

sub _generate_key_field {
    my $self = shift;
    my ($node) = @_;

    my $field = $node->clone(arity => 'field');

    return $self->compile_ast($self->_check_lambda($field));
}

sub _check_lambda {
    my $self = shift;
    my ($var) = @_;

    my $parser = $self->parser;

    my $is_code = $parser->symbol('(name)')->clone(
        arity => 'name',
        id    => '(is_code)',
        line  => $var->line,
    );
    my $run_code = $parser->symbol('(name)')->clone(
        arity => 'name',
        id    => '(run_code)',
        line  => $var->line,
    );

    return $parser->make_ternary(
        $parser->call($is_code, $var->clone),
        $parser->call(
            $run_code,
            $var->clone,
            $parser->vars,
        ),
        $var,
    );
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
