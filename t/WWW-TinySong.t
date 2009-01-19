use Test::More tests => 4;
BEGIN { use_ok('WWW::TinySong') };

my $ua;
ok($ua = WWW::TinySong::ua, 'ua() did not return a true value');

$ua->timeout(10);
$ua->env_proxy;

SKIP: {
    my $conn_ok;
    eval 'use Net::Config qw(%NetConfig); $conn_ok = $NetConfig{test_hosts}';
    skip 'Net::Config needed for network-related tests', 2 if $@;
    skip 'No network connection', 2 unless $conn_ok;

    my @res;
        
    ok(@res = WWW::TinySong::tinysong('we are the champions'),
        'tinysong() did not return a true value');
    like(join('', map {$_->{artist}} @res), qr/queen/i,
        'tinysong() gave unexpected results');
}
