use Test::More tests => 10;
BEGIN { use_ok('WWW::TinySong') };

my $ua;
ok($ua = WWW::TinySong->ua, 'ua() returns true value');
$ua->timeout(30);
$ua->env_proxy;

my $service;
ok($service = WWW::TinySong->service, 'service() returns true value');
like($service, qr(^http://)i, 'service() returns a http URL');

ok(defined(WWW::TinySong->retries), 'retries() is defined');

my $retries = 5;
is(WWW::TinySong->retries($retries), $retries, 'retries() sets correctly');

SKIP: {
    my $conn_ok;
    eval 'use Net::Config qw(%NetConfig); $conn_ok = $NetConfig{test_hosts}';
    skip 'Net::Config needed for network-related tests', 4 if $@;
    skip 'No network connection', 4 unless $conn_ok;

    my @res;

    # basic check
    ok(@res = WWW::TinySong->tinysong('we are the champions'),
        'tinysong() returns true value');
    like(join('', map {$_->{artist}} @res), qr/queen/i,
        'tinysong() gives expected results');

    # imported check
    WWW::TinySong->import('tinysong');
    ok(@res = tinysong('a hard day\'s night'),
        'imported tinysong() returns true value');
    like(join('', map {$_->{artist}} @res), qr/beatles/i,
        'imported tinysong() gives expected results');    
}
