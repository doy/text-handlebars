package Text::Handlebars;
use strict;
use warnings;

use base 'Text::Xslate';

use Scalar::Util 'weaken';
use Try::Tiny;

sub default_helpers {
    my $class = shift;
    return {
        with => sub {
            my ($context, $new_context, $options) = @_;
            return $options->{fn}->($new_context);
        },
        each => sub {
            my ($context, $list, $options) = @_;
            return join '', map { $options->{fn}->($_) } @$list;
        },
        if => sub {
            my ($context, $conditional, $options) = @_;
            return $conditional
                ? $options->{fn}->($context)
                : $options->{inverse}->($context);
        },
        unless => sub {
            my ($context, $conditional, $options) = @_;
            return $conditional
                ? $options->{inverse}->($context)
                : $options->{fn}->($context);
        },
    };
}

sub default_functions {
    my $class = shift;
    return {
        %{ $class->SUPER::default_functions(@_) },
        %{ $class->default_helpers },
        '(is_array)' => sub {
            my ($val) = @_;
            return ref($val) && ref($val) eq 'ARRAY';
        },
        '(is_falsy)' => sub {
            my ($val) = @_;
            if (ref($val) && ref($val) eq 'ARRAY') {
                return @$val == 0;
            }
            else {
                return !$val;
            }
        },
        '(make_array)' => sub {
            my ($length) = @_;
            return [(undef) x $length];
        },
        '(make_hash)' => sub {
            my (%hash) = @_;
            return \%hash;
        },
        '(is_code)' => sub {
            my ($val) = @_;
            return ref($val) && ref($val) eq 'CODE';
        },
        '(new_vars_for)' => sub {
            my ($vars, $value, $i) = @_;

            if (my $ref = ref($value)) {
                if (defined $ref && $ref eq 'ARRAY') {
                    die "no iterator cycle provided?"
                        unless defined $i;

                    $value = ref($value->[$i]) && ref($value->[$i]) eq 'HASH'
                        ? { '.' => $value->[$i], %{ $value->[$i] } }
                        : { '.' => $value->[$i] };

                    $ref = ref($value);
                }

                return $vars unless $ref && $ref eq 'HASH';

                weaken(my $vars_copy = $vars);
                return {
                    '@index' => $i,
                    %$vars,
                    %$value,
                    '..' => $vars_copy,
                };
            }
            else {
                return $vars;
            }
        },
    };
}

sub options {
    my $class = shift;

    my $options = $class->SUPER::options(@_);

    $options->{compiler} = 'Text::Handlebars::Compiler';
    $options->{helpers} = {};

    return $options;
}

sub _register_builtin_methods {
    my $self = shift;
    my ($funcs) = @_;

    weaken(my $weakself = $self);
    $funcs->{'(run_code)'} = sub {
        my ($code, $vars, $open_tag, $close_tag, @args) = @_;
        my $to_render = $code->(@args);
        $to_render = "{{= $open_tag $close_tag =}}$to_render"
            if defined($open_tag) && defined($close_tag) && $close_tag ne '}}';
        return $weakself->render_string($to_render, $vars);
    };
    $funcs->{'(find_file)'} = sub {
        my ($filename) = @_;
        return 1 if try { $weakself->find_file($filename); 1 };
        $filename .= $weakself->{suffix};
        return 1 if try { $weakself->find_file($filename); 1 };
        return 0;
    };
    $funcs->{'(make_block_helper)'} = sub {
        my ($code, $raw_text, $else_raw_text, $hash) = @_;

        my $options = {};
        $options->{fn} = sub {
            my ($new_vars) = @_;
            return $weakself->render_string($raw_text, $new_vars);
        };
        $options->{inverse} = sub {
            my ($new_vars) = @_;
            return $weakself->render_string($else_raw_text, $new_vars);
        };
        $options->{hash} = $hash;

        return sub { $code->(@_, $options); };
    };

    for my $helper (keys %{ $self->{helpers} }) {
        $funcs->{$helper} = $self->{helpers}{$helper};
    }
}

sub _compiler {
    my $self = shift;

    if (!ref($self->{compiler})) {
        my $compiler = $self->SUPER::_compiler(@_);
        $compiler->define_helper(keys %{ $self->{helpers} });
        $compiler->define_helper(keys %{ $self->default_helpers });
        return $compiler;
    }
    else {
        return $self->SUPER::_compiler(@_);
    }
}

sub render_string {
    my $self = shift;
    my ($string, $vars) = @_;

    if (ref($vars) && ref($vars) eq 'HASH') {
        return $self->SUPER::render_string(@_);
    }
    else {
        return $self->SUPER::render_string($string, { '.' => $vars });
    }
}

sub render {
    my $self = shift;
    my ($name, $vars) = @_;

    if (ref($vars) && ref($vars) eq 'HASH') {
        return $self->SUPER::render(@_);
    }
    else {
        return $self->SUPER::render($name, { '.' => $vars });
    }
}

1;
