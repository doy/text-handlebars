package Text::Xslate::Syntax::Handlebars;
use Any::Moose;

use Carp 'confess';
use Text::Xslate::Util qw($STRING neat p);

extends 'Text::Xslate::Parser';

sub _build_identity_pattern { qr/[A-Za-z_][A-Za-z0-9_]*/ }
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

    # 'text' is a something without newlines
    # follwoing a newline, $tag_start, or end of the input
    my $lex_text = qr/\A ( [^\n]*? (?: \n | (?= \Q$tag_start\E ) | \z ) ) /xms;

    my $lex_comment = $self->comment_pattern;
    my $lex_code    = qr/(?: $lex_comment | (?: $STRING | [^'"] ) )/xms;

    my @chunks;

    my $close_tag;
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

                push @chunks, [
                    ($close_tag eq '}}}' ? 'raw_code' : 'code'),
                    $code
                ];

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
        elsif ($input =~ s/\A$lex_text//) {
            push @chunks, [ text => $1 ];
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
        my ($type, $content) = @$chunk;
        if ($type eq 'text') {
            $content =~ s/(["\\])/\\$1/g;
            $code .= qq{print_raw "$content";\n};
        }
        elsif ($type eq 'code') {
            $code .= qq{$content;\n};
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

    my $name = $self->symbol('(name)');
    $name->set_led($self->can('led_name'));
    $name->lbp(1);

    $self->infix('.', 256, $self->can('led_dot'));
    $self->infix('/', 256, $self->can('led_dot'));
}

sub nud_name {
    my $self = shift;
    my ($symbol) = @_;

    if ($symbol->is_defined) {
        return $self->SUPER::nud_name(@_);
    }
    else {
        return $self->nud_variable(@_);
    }
}

sub led_name {
    my $self = shift;
    my ($symbol, $left) = @_;

    if ($left->arity eq 'name') {
        return $self->call($left, $symbol->nud($self));
    }
    else {
        ...
    }
}

sub led_dot {
    my $self = shift;
    my ($symbol, $left) = @_;

    my $token = $self->token;
    if (!$self->is_valid_field($token)) {
        $self->_unexpected("a field name", $token);
    }

    my $dot = $symbol->clone(
        arity  => 'field',
        first  => $left,
        second => $token->clone(arity => 'literal'),
    );

    $self->advance;

    return $dot;
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
