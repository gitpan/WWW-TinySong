#!/usr/bin/perl

use WWW::TinySong qw(tinysong);

for(tinysong("we are the champions")) {
    printf("%s", $_->{song});
    printf(" by %s", $_->{artist}) if $_->{artist};
    printf(" on %s", $_->{album}) if $_->{album};
    printf(" <%s>\n", $_->{url});
}

