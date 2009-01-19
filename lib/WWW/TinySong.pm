package WWW::TinySong;

=head1 NAME

WWW::TinySong - Get free music links from tinysong.com

=head1 SYNOPSIS

  use WWW::TinySong qw(tinysong);

  my $ua = WWW::TinySong::ua;
  $ua->timeout(10);
  $ua->env_proxy;

  for(tinysong("we are the champions")) {
      printf("%s", $_->{song});
      printf(" by %s", $_->{artist}) if $_->{artist};
      printf(" on %s", $_->{album}) if $_->{album};
      printf(" <%s>\n", $_->{url});
  }

=head1 DESCRIPTION

tinysong.com is a web app that can be queried for a song and returns a
tiny URL, allowing you to listen to the song for free online and share
it with friends. L<WWW::TinySong> is a Perl interface to this service,
allowing you to programmatically search its underlying database. (Yes,
for those who are curious, the module currently works by scraping.)

=cut

use 5.006;
use strict;
use warnings;

use Carp;
use CGI;
use Exporter;
use HTML::Parser;

our @EXPORT_OK = qw(tinysong);
our @ISA       = qw(Exporter);
our $VERSION   = '0.04_05';
$VERSION       = eval $VERSION;

my $ua;
my $service = 'http://tinysong.com/';

=head1 FUNCTIONS

The module defines the functions described below. C<tinysong> implements
the main functionality of this module and is the only function that may be
imported. The others are utility functions.

=over 4

=item WWW::TinySong::tinysong( QUERY_STRING [, LIMIT ])

Searches tinysong.com for QUERY_STRING, giving up to LIMIT results. LIMIT
defaults to 10 if not C<defined>. Returns an array in list context or the
top result in scalar context. Return elements are hashrefs with keys
C<qw(album artist song url)>. Their values will be the empty string if not
given by the website. Here's a quick script to demonstrate:

  #!/usr/bin/perl

  use WWW::TinySong qw(tinysong);
  use Data::Dumper;
   
  print Dumper tinysong("a hard day's night", 3);

...and its output on my system at the time of this writing:

  $VAR1 = {
            'album' => 'A Hard Day\'s Night',
            'artist' => 'The Beatles',
            'song' => 'A Hard Day\'s Night',
            'url' => 'http://tinysong.com/21q3'
          };
  $VAR2 = {
            'album' => 'A Hard Day\'s Night',
            'artist' => 'The Beatles',
            'song' => 'And I Love Her',
            'url' => 'http://tinysong.com/2i03'
          };
  $VAR3 = {
            'album' => 'A Hard Day\'s Night',
            'artist' => 'The Beatles',
            'song' => 'If I Fell',
            'url' => 'http://tinysong.com/21q4'
          };

=cut

sub tinysong {
    my($string, $limit) = @_;
    if(wantarray) {
        $limit = 10 unless defined $limit;
    }
    else {
        $limit = 1; # no point in searching for more if only one is needed
    }
    
    my $response = ua()->get(sprintf('%s?s=%s&limit=%d', service(),
        CGI::escape(lc($string)), $limit));
    $response->is_success or croak $response->status_line;

    my @ret           = ();
    my $inside_list   = 0;
    my $current_class = undef;

    my $start_h = sub {
        my $tagname = lc(shift);
        my $attr    = shift;
        if(    $tagname eq 'ul'
            && defined($attr->{id})
            && lc($attr->{id}) eq 'results')
        {
            $inside_list = 1;
        }
        elsif($inside_list) {
            if($tagname eq 'span') {
                my $class = $attr->{class};
                if(defined($class) && $class =~ /^(?:album|artist|song)$/i) {
                    $current_class = lc $class;
                    croak 'Unexpected results while parsing HTML'
                        if !@ret || defined($ret[$#ret]->{$current_class});
                }
            }
            elsif($tagname eq 'a') {
                push @ret, { url => $attr->{href} || '' };
            }
        }
    };

    my $text_h = sub {
        return unless $inside_list && $current_class;
        my $text = shift;
        $ret[$#ret]->{$current_class} = $text;
        undef $current_class;
    };

    my $end_h = sub {
        return unless $inside_list;
        my $tagname = lc(shift);
        if($tagname eq 'ul') {
            $inside_list = 0;
        }
        elsif($tagname eq 'span') {
            undef $current_class;
        }
    };

    my $parser = HTML::Parser->new(
        api_version     => 3,
        start_h         => [$start_h, 'tagname, attr'],
        text_h          => [$text_h, 'text'],
        end_h           => [$end_h, 'tagname'],
        marked_sections => 1,
    );
    my $content = $response->decoded_content || $response->content
        or croak 'Problem reading page content';
    $parser->parse($content);
    $parser->eof;

    for my $res (@ret) {
        $res->{$_} ||= '' for qw(album artist song);
        $res->{album}  =~ s/^\s+on\s//;
        $res->{artist} =~ s/^\s+by\s//;
    }

    return wantarray ? @ret : $ret[0];
}

=item WWW::TinySong::ua( [ USER_AGENT ] )

Returns the user agent object used for all retrievals, first setting
it to USER_AGENT if it's specified. Defaults to a C<new> L<LWP::UserAgent>.
You can customize this object as in the L</SYNOPSIS>.

If you decide to replace the user agent altogether, you don't have to use
a L<LWP::UserAgent>: the only requirement is that the object you use can
C<get> a URL and return a response object.

=cut

sub ua {
    if(@_) {
        $ua = shift;
    }
    elsif(!defined($ua)) {
        eval {
            require LWP::UserAgent;
            $ua = new LWP::UserAgent;
        };
    }
    defined($ua) or carp 'Problem setting user agent';
    return $ua;
}

=item WWW::TinySong::service( [ URL ] )

Returns the web address of the service used by this module, first setting
it to URL if it's specified. Defaults to L<http://tinysong.com/>.

=back

=cut

sub service {
    $service = shift if @_;
    return $service;
}

1;

__END__

=head1 BE NICE TO THE SERVERS

Please don't abuse the servers. If you anticipate making a large number of
requests, don't make them too frequently. There are several CPAN modules
that can help you make sure your code is nice. Try, for example,
L<LWP::RobotUA> as the user agent:

  use WWW::TinySong qw(tinysong);
  use LWP::RobotUA;
  
  my $ua = LWP::RobotUA->new('my-nice-robot/0.1', 'me@example.org');
  
  WWW::TinySong::ua($ua);
  
  # tinysong() should now be well-behaved

=head1 SEE ALSO

L<http://tinysong.com/>, L<LWP::UserAgent>, L<LWP::RobotUA>

=head1 BUGS

Please report them:
L<http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-TinySong>

=head1 AUTHOR

Miorel-Lucian Palii, E<lt>mlpalii@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Miorel-Lucian Palii

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
