use Test::More tests => 4;
BEGIN { use_ok('WWW::TinySong') };

my $ts;
ok($ts = WWW::TinySong->new, "constructor did not return a true value");

$ts->timeout(10);
$ts->env_proxy;

SKIP: {
    my $conn_ok;
    eval 'use Net::Config qw(%NetConfig); $conn_ok = $NetConfig{test_hosts}';
    skip "Net::Config needed for network-related tests", 2 if $@;
    skip "No network connection", 2 unless $conn_ok;

    my @res;
    ok(@res = $ts->song_search("never gonna give you up"),
        "song_search() did not return a true value");
    like(join('', map {$_->{artist}} @res), qr/rick astley/i,
        "song_search() gave unexpected results");
}
