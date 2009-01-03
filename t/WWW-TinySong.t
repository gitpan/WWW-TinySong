use Test::More tests => 4;
BEGIN { use_ok('WWW::TinySong') };

my $ts;
ok($ts = WWW::TinySong->new, "new test");
$ts->timeout(10);
$ts->env_proxy;

my @res;
ok(@res = $ts->song_search("Never Gonna Give You Up"), "song_search test");
like(join('', map {$_->{artist}} @res), qr/rick astley/i, "result check");

