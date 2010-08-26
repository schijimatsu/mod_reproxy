use strict;
use warnings;

use Test::Httpd::Apache2;
use Test::More;
use Test::TCP;
use Plack::Loader;
use LWP::UserAgent;

my $httpd = Test::Httpd::Apache2->new(
    required_modules => [ qw(cgi mime reproxy) ],
    custom_conf => << "EOT",
DocumentRoot t/assets
AddHandler cgi-script .cgi
Reproxy On
EOT
);

my $reproxy_cgi = "http://@{[$httpd->listen]}/reproxy.cgi";

sub do_test ($$) {
    my ($server_app, $check_response) = @_;
    test_tcp(
        server => sub {
            my $port = shift;
            Plack::Loader->auto(
                host => '127.0.0.1',
                port => $port,
            )->run($server_app);
        },
        client => sub {
            my $port = shift;
            my $r = LWP::UserAgent->new->get(
                "$reproxy_cgi?url=http://127.0.0.1:$port/&type=text/plain",
            );
            $check_response->($r);
        },
    );
}

# test 200 OK
do_test
    sub {
        return [ 200, [ 'Content-Type', 'text/x-hogehoge' ], [ 'hello' ] ];
    },
    sub {
        my $r = shift;
        is $r->code, 200, '200 status';
        is $r->content_type, 'text/plain', '200 content type';
        is $r->content, 'hello', '200 content';
    };

# test 404 => 500
do_test
    sub {
        return [ 404, [ 'Content-Type', 'text/plain' ], [ 'not found' ] ];
    },
    sub {
        my $r = shift;
        is $r->code, 500, '404 => 500';
    };

# test 500 => 500
do_test
    sub {
        return [ 500, [ 'Content-Type', 'text/plain' ], [ 'internal error' ] ];
    },
    sub {
        my $r = shift;
        is $r->code, 500, '500 => 500';
    };

# test 503 => 503
do_test
    sub {
        return [ 503, [ 'Content-Type', 'text/plain' ], [ 'down now' ] ];
    },
    sub {
        my $r = shift;
        is $r->code, 503, '503 => 503';
    };

done_testing;
