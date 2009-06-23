use Test::More tests => 18;
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
    skip 'Net::Config needed for network-related tests', 12 if $@;
    skip 'No network connection', 12 unless $conn_ok;

    my($res, @res);

    # tinysong() check
    ok(@res = WWW::TinySong->tinysong('we are the champions'),
        'tinysong() returns true value');
    like(join('', map {$_->{artist}} @res), qr/queen/i,
        'tinysong() gives expected results');

    # link() check
    ok($res = WWW::TinySong->link('dreams'), 'link() returns true value');

    # a() check
    ok($res = WWW::TinySong->a('come go with me'), 'a() returns true value');
    
    # b() check
    ok($res = WWW::TinySong->b('feel good inc'), 'b() returns true value');
    like($res->{artistName}, qr/gorillaz/i, 'b() gives expected results');
    
    # search() check
    ok(@res = WWW::TinySong->search('three little birds'),
        'search() returns true value');
    like(join('', map {$_->{artistName}} @res), qr/bob marley/i,
        'search() gives expected results');
    
    # s() check
    ok(@res = WWW::TinySong->s('stairway to heaven'),
        's() returns true value');
    like(join('', map {$_->{artistName}} @res), qr/led zeppelin/i,
        's() gives expected results');

    # scrape() check
    ok(@res = WWW::TinySong->scrape('a hard day\'s night'),
        'scrape() returns true value');
    like(join('', map {$_->{artistName}} @res), qr/beatles/i,
        'scrape() gives expected results');
}
