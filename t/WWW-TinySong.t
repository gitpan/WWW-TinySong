use Test::More tests => 6;
BEGIN { use_ok('WWW::TinySong') };

my $ts;
ok($ts = WWW::TinySong->new, "constructor did not return a true value");

$ts->timeout(10);
$ts->env_proxy;

SKIP: {
    my $conn_ok;
    eval 'use Net::Config qw(%NetConfig); $conn_ok = $NetConfig{test_hosts}';
    skip "Net::Config needed for network-related tests", 4 if $@;
    skip "No network connection", 4 unless $conn_ok;

    my @res;
    
    ok(@res = $ts->tinysong("never gonna give you up"),
        "object-oriented tinysong() did not return a true value");
    like(join('', map {$_->{artist}} @res), qr/rick astley/i,
        "object-oriented tinysong() gave unexpected results");
        
    ok(@res = WWW::TinySong::tinysong("never gonna give you up"),
        "functional tinysong() did not return a true value");
    like(join('', map {$_->{artist}} @res), qr/rick astley/i,
        "functional tinysong() gave unexpected results");
}
