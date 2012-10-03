#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Handlebars;

use Test::Requires 'JSON', 'Path::Class';

for my $file (dir('t', 'mustache-spec', 'specs')->children) {
    next unless $file =~ /\.json$/;
    next if $file->basename =~ /^~/; # for now
    next if $file->basename =~ /partials/;
    local $TODO = "unimplemented" if $file->basename =~ /delimiters/;
    my $tests = decode_json($file->slurp);
    diag("running " . $file->basename . " tests");
    for my $test (@{ $tests->{tests} }) {
        render_ok(
            $test->{template},
            $test->{data},
            $test->{expected},
            "$test->{name}: $test->{desc}"
        );
    }
}

done_testing;
