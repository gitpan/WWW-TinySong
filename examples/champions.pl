#!/usr/bin/perl

use WWW::TinySong;

for(WWW::TinySong->search("we are the champions")) {
    printf("%s", $_->{songName});
    printf(" by %s", $_->{artistName});
    printf(" on %s", $_->{albumName}) if $_->{albumName};
    printf(" <%s>\n", $_->{tinysongLink});
}
