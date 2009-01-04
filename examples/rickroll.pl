#!/usr/bin/perl

use WWW::TinySong;

my $ts = WWW::TinySong->new;
$ts->timeout(10);
$ts->env_proxy;

for($ts->song_search("Never Gonna Give You Up")) {
    printf("%s", $_->{song});
    printf(" by %s", $_->{artist}) if $_->{artist};
    printf(" on %s", $_->{album}) if $_->{album};
    printf(" <%s>\n", $_->{url});
}

