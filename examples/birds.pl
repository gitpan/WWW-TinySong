#!/usr/bin/perl

use WWW::TinySong;
use Data::Dumper;

print Dumper(WWW::TinySong->search("three little birds", 3));
