#!/usr/bin/perl

use WWW::TinySong qw(tinysong);
use Data::Dumper;

print Dumper tinysong("a hard day's night", 3);
