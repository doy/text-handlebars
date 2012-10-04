package Text::Xslate::Syntax::Handlebars;
use Any::Moose;

use Carp 'confess';
use Text::Xslate::Util qw($DEBUG $STRING neat p);

extends 'Text::Xslate::Parser';

use constant _DUMP_PROTO => scalar($DEBUG =~ /\b dump=proto \b/xmsi);

my $nl = qr/\x0d?\x0a/;

sub _build_identity_pattern { qr/[A-Za-z_][A-Za-z0-9_?]*/ }
sub _build_comment_pattern  { qr/\![^;]*/                }

sub _build_line_start { undef }
sub _build_tag_start  { '{{'  }
sub _build_tag_end    { '}}'  }

sub _build_shortcut_table { +{} }

sub split_tags {
    my $self = shift;
    my ($input) = @_;

    my $tag_start = $self->tag_start;
    my $tag_end   = $self->tag_end;

    my $lex_comment = $self->comment_pattern;
    my $lex_code    = qr/(?: $lex_comment | (?: $STRING | [^'"] ) )/xms;

    my @chunks;

    my @raw_text;
    my @delimiters;

    my $close_tag;
    my $standalone = 1;
    while ($input) {
        if ($close_tag) {
            my $start = 0;
            my $pos;
            while(($pos = index $input, $close_tag, $start) >= 0) {
                my $code = substr $input, 0, $pos;
                $code =~ s/$lex_code//g;
                if(length($code) == 0) {
                    last;
                }
                $start = $pos + 1;
            }

            if ($pos >= 0) {
                my $code = substr $input, 0, $pos, '';
                $input =~ s/\A\Q$close_tag//
                    or die "Oops!";

                my @extra;

                my $autochomp = $code =~ m{^[!#^/=>]};

                if ($code =~ s/^=\s*([^\s]+)\s+([^\s]+)\s*=$//) {
                    ($tag_start, $tag_end) = ($1, $2);
                }
                elsif ($code =~ /^=/) {
                    die "Invalid delimiter tag: $code";
                }

                if ($autochomp && $standalone) {
                    if ($input =~ /\A\s*(?:\n|\z)/) {
                        $input =~ s/\A$nl//;
                        if (@chunks > 0 && $chunks[-1][0] eq 'text' && $code !~ m{^>}) {
                            $chunks[-1][1] =~ s/^(?:(?!\n)\s)*\z//m;
                            if (@raw_text) {
                                $raw_text[-1] =~ s/^(?:(?!\n)\s)*\z//m;
                            }
                        }
                    }
                }
                else {
                    $standalone = 0;
                }

                if ($code =~ m{^/}) {
                    push @extra, pop @raw_text;
                    push @extra, pop @delimiters;
                    if (@raw_text) {
                        $raw_text[-1] .= $extra[0];
                    }
                }
                if (@raw_text) {
                    $raw_text[-1] .= $tag_start . $code . $tag_end;
                }
                if ($code =~ m{^[#^]}) {
                    push @raw_text, '';
                    push @delimiters, [$tag_start, $tag_end];
                }

                if (length($code)) {
                    push @chunks, [
                        ($close_tag eq '}}}' ? 'raw_code' : 'code'),
                        $code,
                        @extra,
                    ];
                }

                undef $close_tag;
            }
            else {
                last; # the end tag is not found
            }
        }
        elsif ($input =~ s/\A\Q$tag_start//) {
            if ($tag_start eq '{{' && $input =~ s/\A\{//) {
                $close_tag = '}}}';
            }
            else {
                $close_tag = $tag_end;
            }
        }
        elsif ($input =~ s/\A([^\n]*?(?:\n|(?=\Q$tag_start\E)|\z))//) {
            my $text = $1;
            if (length($text)) {
                push @chunks, [ text => $text ];

                if ($standalone) {
                    $standalone = $text =~ /(?:^|\n)\s*$/;
                }
                else {
                    $standalone = $text =~ /\n\s*$/;
                }

                if (@raw_text) {
                    $raw_text[-1] .= $text;
                }
            }
        }
        else {
            confess "Oops: unreached code, near " . p($input);
        }
    }

    if ($close_tag) {
        # calculate line number
        my $orig_src = $_[0];
        substr $orig_src, -length($input), length($input), '';
        my $line = ($orig_src =~ tr/\n/\n/);
        $self->_error("Malformed templates detected",
            neat((split /\n/, $input)[0]), ++$line,
        );
    }

    return @chunks;
}

sub preprocess {
    my $self = shift;
    my ($input) = @_;

    my @chunks = $self->split_tags($input);

    my $code = '';
    for my $chunk (@chunks) {
        my ($type, $content, $raw_text, $delimiters) = @$chunk;
        if ($type eq 'text') {
            $content =~ s/(["\\])/\\$1/g;
            $code .= qq{print_raw "$content";\n}
                if length($content);
        }
        elsif ($type eq 'code') {
            my $extra = '';
            if ($content =~ s{^/}{}) {
                $chunk->[2] =~ s/(["\\])/\\$1/g;
                $chunk->[3][0] =~ s/(["\\])/\\$1/g;
                $chunk->[3][1] =~ s/(["\\])/\\$1/g;

                $extra = '"'
                       . join('" "', $chunk->[2], @{ $chunk->[3] })
                       . '"';
                $code .= qq{/$extra $content;\n};
            }
            else {
                $code .= qq{$content;\n};
            }
        }
        elsif ($type eq 'raw_code') {
            $code .= qq{&$content;\n};
        }
        else {
            $self->_error("Oops: Unknown token: $content ($type)");
        }
    }

    print STDOUT $code, "\n" if _DUMP_PROTO;
    return $code;
}

# XXX advance has some syntax special cases in it, probably need to override
# it too eventually

sub init_symbols {
    my $self = shift;

    for my $type (qw(name variable literal)) {
        my $symbol = $self->symbol("($type)");
        $symbol->set_led($self->can("led_$type"));
        $symbol->lbp(10);
    }

    $self->infix('.', 256, $self->can('led_dot'));
    $self->infix('/', 256, $self->can('led_dot'));

    $self->symbol('.')->set_nud($self->can('nud_dot'));
    $self->symbol('this')->set_nud($self->can('nud_dot'));

    $self->symbol('#')->set_std($self->can('std_block'));
    $self->symbol('^')->set_std($self->can('std_block'));
    $self->prefix('/', 0)->is_block_end(1);

    $self->symbol('>')->set_std($self->can('std_partial'));

    $self->prefix('&', 0)->set_nud($self->can('nud_mark_raw'));
    $self->prefix('..', 0)->set_nud($self->can('nud_uplevel'));
}

sub nud_name {
    my $self = shift;
    my ($symbol) = @_;

    my $name = $self->SUPER::nud_name($symbol);

    return $self->call($name);
}

sub led_name {
    my $self = shift;

    $self->_unexpected("a variable or literal", $self->token);
}

sub nud_variable {
    my $self = shift;
    my ($symbol) = @_;

    my $var = $self->SUPER::nud_variable(@_);

    return $self->check_lambda($var);
}

sub led_variable {
    my $self = shift;
    my ($symbol, $left) = @_;

    if ($left->arity ne 'call') {
        $self->_error("Unexpected variable found", $symbol);
    }

    my $var = $symbol;

    # was this actually supposed to be an expression?
    # for instance, {{foo bar baz.quux blorg}}
    # if we get here for baz, we need to make sure we end up with all of
    # baz.quux
    # this basically just reimplements $self->expression, except starting
    # partway through
    while ($self->token->lbp > $var->lbp) {
        my $token = $self->token;
        $self->advance;
        $var = $token->led($self, $var);
    }

    push @{ $left->second }, $self->check_lambda($var);

    return $left;
}

sub led_literal {
    my $self = shift;
    my ($symbol, $left) = @_;

    if ($left->arity ne 'call') {
        $self->_error("Unexpected literal found", $symbol);
    }

    push @{ $left->second }, $symbol;

    return $left;
}

sub led_dot {
    my $self = shift;
    my ($symbol, $left) = @_;

    my $dot = $self->make_field_lookup($left, $self->token, $symbol);

    $self->advance;

    return $self->check_lambda($dot);
}

sub nud_dot {
    my $self = shift;
    my ($symbol) = @_;

    return $symbol->clone(arity => 'variable', id => '.');
}

sub std_block {
    my $self = shift;
    my ($symbol) = @_;

    my $inverted = $symbol->id eq '^';

    my $name = $self->expression(0);
    # variable lookups are parsed into a ternary expression, hence arity 'if'
    if ($name->arity eq 'if') {
        $name = $name->third;
    }

    if ($name->arity ne 'variable' && $name->arity ne 'field' && $name->arity ne 'call') {
        $self->_unexpected("opening block name", $self->token);
    }
    my $name_string = $self->_field_to_string($name);

    $self->advance(';');

    my $body = $self->statements;

    $self->advance('/');

    my $raw_text = $self->token;
    $self->advance;
    my $open_tag = $self->token;
    $self->advance;
    my $close_tag = $self->token;
    $self->advance;

    my $closing_name = $self->expression(0);
    if ($closing_name->arity eq 'if') {
        $closing_name = $closing_name->third;
    }

    if ($closing_name->arity ne 'variable' && $closing_name->arity ne 'field' && $closing_name->arity ne 'call') {
        $self->_unexpected("closing block name", $self->token);
    }
    my $closing_name_string = $self->_field_to_string($closing_name);

    if ($name_string ne $closing_name_string) {
        $self->_unexpected('/' . $name_string, $self->token);
    }

    $self->advance(';');

    if ($name->arity eq 'call') {
        return $self->print_raw(
            $self->call(
                '(run_block_helper)',
                $self->symbol($name->first->id)->clone,
                $raw_text->clone,
                $self->symbol('(vars)')->clone(arity => 'vars'),
                @{ $name->second },
            ),
        );
    }

    my $iterations = $inverted
        ? ($self->make_ternary(
              $self->call('(is_array)', $name->clone),
              $self->make_ternary(
                  $self->call('(is_empty_array)', $name->clone),
                  $self->call(
                      '(make_array)',
                      $self->symbol('(literal)')->clone(id => 1),
                  ),
                  $self->call(
                      '(make_array)',
                      $self->symbol('(literal)')->clone(id => 0),
                  ),
              ),
              $self->make_ternary(
                  $name->clone,
                  $self->call(
                      '(make_array)',
                      $self->symbol('(literal)')->clone(id => 0),
                  ),
                  $self->call(
                      '(make_array)',
                      $self->symbol('(literal)')->clone(id => 1),
                  ),
              ),
           ))
        : ($self->make_ternary(
              $self->call('(is_array)', $name->clone),
              $name->clone,
              $self->make_ternary(
                  $name->clone,
                  $self->call(
                      '(make_array)',
                      $self->symbol('(literal)')->clone(id => 1),
                  ),
                  $self->call(
                      '(make_array)',
                      $self->symbol('(literal)')->clone(id => 0),
                  ),
              ),
           ));

    my $loop_var = $self->symbol('(variable)')->clone(id => '(block)');

    my $body_block = [
        $symbol->clone(
            arity => 'block',
            first => ($inverted
                ? (undef)
                : ([
                       $self->call(
                           '(new_vars_for)',
                           $self->symbol('(vars)')->clone(arity => 'vars'),
                           $name->clone,
                           $self->symbol('(iterator)')->clone(
                               arity => 'iterator',
                               id    => '$~(block)',
                               first => $loop_var,
                           ),
                       ),
                   ])
            ),
            second => $body,
        ),
    ];

    return $self->make_ternary(
        $self->call('(is_code)', $name->clone),
        $self->print_raw(
            $self->call(
                '(run_code)',
                $name->clone,
                $self->symbol('(vars)')->clone(arity => 'vars'),
                $open_tag->clone,
                $close_tag->clone,
                $raw_text->clone,
            ),
        ),
        $self->symbol('(for)')->clone(
            arity  => 'for',
            first  => $iterations,
            second => [$loop_var],
            third  => $body_block,
        ),
    );
}

sub nud_mark_raw {
    my $self = shift;
    my ($symbol) = @_;

    return $self->symbol('mark_raw')->clone(
        line => $symbol->line,
    )->nud($self);
}

sub nud_uplevel {
    my $self = shift;
    my ($symbol) = @_;

    return $symbol->clone(arity => 'variable');
}

sub std_partial {
    my $self = shift;
    my ($symbol) = @_;

    my $partial = $self->token->clone(arity => 'literal');
    $self->advance;

    return $self->make_ternary(
        $self->call('(find_file)', $partial->clone),
        $symbol->clone(
            arity => 'include',
            id    => 'include',
            first => $partial,
        ),
        $symbol->clone(
            arity => 'literal',
            id    => '',
        ),
    );
}

sub undefined_name {
    my $self = shift;
    my ($name) = @_;

    return $self->symbol('(variable)')->clone(id => $name);
}

sub define_function {
    my $self = shift;
    my (@names) = @_;

    $self->SUPER::define_function(@_);
    for my $name (@names) {
        my $symbol = $self->symbol($name);
        $symbol->set_nud($self->can('nud_name'));
        $symbol->set_led($self->can('led_name'));
        $symbol->lbp(10);
    }

    return;
}

sub is_valid_field {
    my $self = shift;
    my ($field) = @_;

    # undefined symbols are all treated as variables - see undefined_name
    return 1 if $field->arity eq 'variable';
    # allow ../../foo
    return 1 if $field->id eq '..';

    return;
}

sub make_field_lookup {
    my $self = shift;
    my ($var, $field, $dot) = @_;

    if (!$self->is_valid_field($field)) {
        $self->_unexpected("a field name", $field);
    }

    $dot ||= $self->symbol('.');

    return $dot->clone(
        arity  => 'field',
        first  => $var,
        second => $field->clone(arity => 'literal'),
    );
}

sub make_ternary {
    my $self = shift;
    my ($if, $then, $else) = @_;
    return $self->symbol('?:')->clone(
        arity  => 'if',
        first  => $if,
        second => $then,
        third  => $else,
    );
}

sub print_raw {
    my $self = shift;
    return $self->print(@_)->clone(id => 'print_raw');
}

sub check_lambda {
    my $self = shift;
    my ($var) = @_;

    return $self->make_ternary(
        $self->call('(is_code)', $var->clone),
        $self->call(
            '(run_code)',
            $var->clone,
            $self->symbol('(vars)')->clone(arity => 'vars'),
        ),
        $var,
    );
}

sub _field_to_string {
    my $self = shift;
    my ($symbol) = @_;

    # undo check_lambda
    return $self->_field_to_string($symbol->third)
        if $symbol->arity eq 'if';

    # name and variable can just be returned
    return $symbol->id
        unless $symbol->arity eq 'field';

    # field accesses should recurse on the first and append the second
    return $self->_field_to_string($symbol->first) . '.' . $symbol->second->id;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
