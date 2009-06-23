#!/usr/bin/perl

use WWW::TinySong;
use Data::Dumper;

print Dumper(WWW::TinySong->scrape("a hard day's night", 3));
