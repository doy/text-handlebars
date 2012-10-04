package Text::Handlebars;
use strict;
use warnings;

use base 'Text::Xslate';

use Scalar::Util 'weaken';
use Try::Tiny;

sub default_functions {
    my $class = shift;
    return {
        %{ $class->SUPER::default_functions(@_) },
        '(is_array)' => sub {
            my ($val) = @_;
            return ref($val) && ref($val) eq 'ARRAY';
        },
        '(is_empty_array)' => sub {
            my ($val) = @_;
            return @$val == 0;
        },
        '(make_array)' => sub {
            my ($length) = @_;
            return [(undef) x $length];
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

                    $value = ref($value->[$i])
                        ? $value->[$i]
                        : { '.' => $value->[$i] };

                    $ref = ref($value);
                }

                return $vars unless $ref && $ref eq 'HASH';

                weaken(my $vars_copy = $vars);
                return {
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
    $options->{function} = {
        ($options->{function} ? %{ $options->{function} } : ()),
        with => sub {
            my ($context, $new_context, $options) = @_;
            return $options->{fn}->($new_context);
        },
        each => sub {
            my ($context, $list, $options) = @_;

            my $ret = '';
            for my $new_context (@$list) {
                $ret .= $options->{fn}->($new_context);
            }

            return $ret;
        },
        if => sub {
            my ($context, $conditional, $options) = @_;
            if ($conditional) {
                return $options->{fn}->($context);
            }
            return '';
        },
        unless => sub {
            my ($context, $conditional, $options) = @_;
            unless ($conditional) {
                return $options->{fn}->($context);
            }
            return '';
        },
    },

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
    $funcs->{'(run_block_helper)'} = sub {
        my ($code, $raw_text, $vars, @args) = @_;

        my $recurse = sub {
            my ($new_vars) = @_;
            return $weakself->render_string($raw_text, $new_vars);
        };

        return $code->($vars, @args, { fn => $recurse });
    };
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
