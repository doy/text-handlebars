package Text::Xslate::Syntax::Handlebars;
use Any::Moose;

use Carp 'confess';
use Text::Xslate::Util qw($STRING neat p);

extends 'Text::Xslate::Parser';

my $nl = qr/\x0d?\x0a/;

sub _build_identity_pattern { qr/[A-Za-z_][A-Za-z0-9_?]*/ }
sub _build_comment_pattern  { qr/\![^;]*/                }

sub _build_line_start { undef }
sub _build_tag_start  { '{{'  } # XXX needs to be modifiable
sub _build_tag_end    { '}}'  } # XXX needs to be modifiable

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
                        }
                    }
                }
                else {
                    $standalone = 0;
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
            if (@$chunk > 2) {
                $chunk->[2] =~ s/(["\\])/\\$1/g;
                $chunk->[3][0] =~ s/(["\\])/\\$1/g;
                $chunk->[3][1] =~ s/(["\\])/\\$1/g;

                $extra = ' "'
                       . join('" "', $chunk->[2], @{ $chunk->[3] })
                       . '"';
            }
            $code .= qq{$content$extra;\n};
        }
        elsif ($type eq 'raw_code') {
            $code .= qq{mark_raw $content;\n};
        }
        else {
            $self->_error("Oops: Unknown token: $content ($type)");
        }
    }

    return $code;
}

# XXX advance has some syntax special cases in it, probably need to override
# it too eventually

sub init_symbols {
    my $self = shift;

    $self->infix('.', 256, $self->can('led_dot'));
    $self->infix('/', 256, $self->can('led_dot'));

    $self->symbol('.')->set_nud($self->can('nud_dot'));

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

    if ($symbol->is_defined) {
        return $self->call(
            $self->SUPER::nud_name($symbol),
            # XXX this won't handle multiple arguments
            $self->expression($symbol->lbp),
        );
    }
    else {
        return $self->nud_variable(@_);
    }
}

sub nud_variable {
    my $self = shift;
    my ($symbol) = @_;

    my $var = $self->SUPER::nud_variable(@_);

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

sub led_dot {
    my $self = shift;
    my ($symbol, $left) = @_;

    my $dot = $self->make_field_lookup($left, $self->token, $symbol);

    $self->advance;

    return $dot;
}

sub nud_dot {
    my $self = shift;
    my ($symbol) = @_;

    return $symbol->clone(arity => 'variable');
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

    if ($name->arity ne 'variable' && $name->arity ne 'field') {
        $self->_unexpected("opening block name", $self->token);
    }
    $self->advance(';');

    my $body = $self->statements;

    $self->advance('/');
    # 1 so that i pick up names and field accesses, but not literals
    # closing tags are followed by a literal string containing their raw text
    my $closing_name = $self->expression(1);
    if ($closing_name->arity eq 'if') {
        $closing_name = $closing_name->third;
    }

    if ($closing_name->arity ne 'variable' && $closing_name->arity ne 'field') {
        $self->_unexpected("closing block name", $self->token);
    }
    if ($closing_name->id ne $name->id) { # XXX
        $self->_unexpected('/' . $name->id, $self->token);
    }

    my $raw_text = $self->token;
    $self->advance;
    my $open_tag = $self->token;
    $self->advance;
    my $close_tag = $self->token;
    $self->advance;

    $self->advance(';');

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

    return $self->call('mark_raw', $self->expression(0));
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

sub define_function {
    my $self = shift;
    my (@names) = @_;

    $self->SUPER::define_function(@_);
    for my $name (@names) {
        $self->symbol($name)->set_nud($self->can('nud_name'));
    }

    return;
}

sub is_valid_field {
    my $self = shift;
    my ($field) = @_;

    return 1 if $field->id eq '..';
    return $self->SUPER::is_valid_field(@_);
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

if (0) {
    require Devel::STDERR::Indent;
    my @stack;
    for my $method (qw(statements statement expression_list expression)) {
        before $method => sub {
            warn "entering $method";
            push @stack, Devel::STDERR::Indent::indent();
        };
        after $method => sub {
            pop @stack;
            warn "leaving $method";
        };
    }
    after advance => sub {
        my $self = shift;
        warn $self->token->id;
    };
    around parse => sub {
        my $orig = shift;
        my $self = shift;
        my $ast = $self->$orig(@_);
        use Data::Dump; ddx($ast);
        return $ast;
    };
    around preprocess => sub {
        my $orig = shift;
        my $self = shift;
        my $code = $self->$orig(@_);
        warn $code;
        return $code;
    };
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
