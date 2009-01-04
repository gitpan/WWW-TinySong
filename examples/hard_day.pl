#!/usr/bin/perl

use WWW::TinySong;
use Data::Dumper;
  
print Dumper(WWW::TinySong->new->song_search("a hard day's night", 3));
