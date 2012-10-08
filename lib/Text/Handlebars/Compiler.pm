package Text::Handlebars::Compiler;
use Any::Moose;

extends 'Text::Xslate::Compiler';

use Try::Tiny;

has '+syntax' => (
    default => 'Handlebars',
);

sub define_helper { shift->parser->define_helper(@_) }

sub _generate_block_body {
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

    return $self->compile_ast($self->check_lambda($var));
}

sub _generate_key_field {
    my $self = shift;
    my ($node) = @_;

    my $field = $node->clone(arity => 'field');

    return $self->compile_ast($self->check_lambda($field));
}

sub _generate_call {
    my $self = shift;
    my ($node) = @_;

    if ($node->is_helper) {
        my @args;
        my @hash;
        for my $arg (@{ $node->second }) {
            if ($arg->arity eq 'pair') {
                push @hash, $arg->first, $arg->second;
            }
            else {
                push @args, $arg;
            }
        }

        my $hash = $self->call($node, '(make_hash)', @hash);

        unshift @args, $self->vars;

        if ($node->is_block_helper) {
            push @{ $node->first->second }, $hash;
            $node->second(\@args);
        }
        else {
            $node->second([ @args, $hash ]);
        }
    }

    return $self->SUPER::_generate_call($node);
}

sub _generate_partial {
    my $self = shift;
    my ($node) = @_;

    return $self->compile_ast(
        $self->make_ternary(
            $self->call($node, '(find_file)', $node->first->clone),
            $node->clone(
                arity => 'include',
                id    => 'include',
                first => $self->call($node, '(find_file)', $node->first),
            ),
            $self->parser->literal(''),
        ),
    );
}

sub _generate_for {
    my $self = shift;
    my ($node) = @_;

    my @opcodes = $self->SUPER::_generate_for(@_);
    return (
        @opcodes,
        $self->opcode('nil'),
    );
}

sub _generate_block {
    my $self = shift;
    my ($node) = @_;

    my $name = $node->first;
    my %block = %{ $node->second };

    if ($name->arity eq 'call') {
        return $self->compile_ast(
            $name->clone(
                first => $self->call(
                    $node,
                    '(make_block_helper)',
                    $name->first,
                    $block{if}{raw_text}->clone,
                    ($block{else}
                        ? $block{else}{raw_text}->clone
                        : $self->parser->literal('')),
                ),
                is_block_helper => 1,
            ),
        );
    }

    my $iterations = $self->make_ternary(
        $self->call($node, '(is_falsy)', $name->clone),
        $self->call($node, '(make_array)', $self->parser->literal(1)),
        $self->make_ternary(
            $self->call($node, 'is_array_ref', $name->clone),
            $name->clone,
            $self->call($node, '(make_array)', $self->parser->literal(1)),
        ),
    );

    my $loop_var = $self->parser->symbol('(loop_var)')->clone(arity => 'variable');

    my $body_block = [
        $self->make_ternary(
            $self->call($node, '(is_falsy)', $name->clone),
            $name->clone(
                arity  => 'block_body',
                first  => undef,
                second => [ $block{else}{body} ],
            ),
            $name->clone(
                arity  => 'block_body',
                first  => [
                    $self->call(
                        $node,
                        '(new_vars_for)',
                        $self->vars,
                        $name->clone,
                        $self->iterator_index,
                    ),
                ],
                second => [ $block{if}{body} ],
            ),
        ),
    ];

    my $var = $name->clone(arity => 'variable');
    return $self->compile_ast(
        $self->make_ternary(
            $self->call($node, '(is_code)', $var->clone),
            $self->call(
                $node,
                '(run_code)',
                $var->clone,
                $self->vars,
                $block{if}{open_tag}->clone,
                $block{if}{close_tag}->clone,
                $block{if}{raw_text}->clone,
            ),
            $self->parser->symbol('(for)')->clone(
                arity  => 'for',
                first  => $iterations,
                second => [$loop_var],
                third  => $body_block,
            ),
        ),
    );
}

sub call {
    my $self = shift;
    my ($node, $name, @args) = @_;

    my $code = $self->parser->symbol('(name)')->clone(
        arity => 'name',
        id    => $name,
        line  => $node->line,
    );

    return $self->parser->call($code, @args);
}

sub make_ternary {
    my $self = shift;
    my ($if, $then, $else) = @_;
    return $self->parser->symbol('?:')->clone(
        arity  => 'if',
        first  => $if,
        second => $then,
        third  => $else,
    );
}

sub vars {
    my $self = shift;
    return $self->parser->symbol('(vars)')->clone(arity => 'vars');
}

sub iterator_index {
    my $self = shift;

    return $self->parser->symbol('(iterator)')->clone(
        arity => 'iterator',
        id    => '$~(loop_var)',
        first => $self->parser->symbol('(loop_var)')->clone,
    ),
}

sub check_lambda {
    my $self = shift;
    my ($var) = @_;

    return $self->make_ternary(
        $self->call($var, '(is_code)', $var->clone),
        $self->call($var, '(run_code)', $var->clone, $self->vars),
        $var,
    );
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

=for Pod::Coverage
  call
  check_lambda
  define_helper
  iterator_index
  make_ternary
  vars

=cut

1;
