package Text::Handlebars;
use strict;
use warnings;

use base 'Text::Xslate';

use Scalar::Util 'weaken';

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
        '(new_vars_for)' => sub {
            my ($vars, $value, $i) = @_;
            $i = 0 unless defined $i; # XXX

            if (my $ref = ref($value)) {
                if (defined $ref && $ref eq 'ARRAY') {
                    die "no iterator cycle provided?"
                        unless defined $i;
                    $value = $value->[$i];
                    $ref   = ref($value);
                }

                die "invalid value: $value"
                    if !defined($ref) || $ref ne 'HASH';

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
    return $options;
}

1;
