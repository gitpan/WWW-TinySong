use Test::More tests => 6;
BEGIN { use_ok('WWW::TinySong') };

my $ts;
ok($ts = WWW::TinySong->new, 'new() did not return a true value');

$ts->timeout(10);
$ts->env_proxy;

SKIP: {
    my $conn_ok;
    eval 'use Net::Config qw(%NetConfig); $conn_ok = $NetConfig{test_hosts}';
    skip 'Net::Config needed for network-related tests', 4 if $@;
    skip 'No network connection', 4 unless $conn_ok;

    my @res;
    
    ok(@res = $ts->tinysong('we are the champions'),
        'object-oriented tinysong() did not return a true value');
    like(join('', map {$_->{artist}} @res), qr/queen/i,
        'object-oriented tinysong() gave unexpected results');
        
    ok(@res = WWW::TinySong::tinysong('we are the champions'),
        'function-oriented tinysong() did not return a true value');
    like(join('', map {$_->{artist}} @res), qr/queen/i,
        'function-oriented tinysong() gave unexpected results');
}
