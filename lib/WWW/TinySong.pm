package WWW::TinySong;

=head1 NAME

WWW::TinySong - Get free music links from tinysong.com

=head1 SYNOPSIS

  # basic use

  use WWW::TinySong qw(tinysong);

  for(tinysong("we are the champions")) {
      printf("%s", $_->{song});
      printf(" by %s", $_->{artist}) if $_->{artist};
      printf(" on %s", $_->{album}) if $_->{album};
      printf(" <%s>\n", $_->{url});
  }

  # customize the user agent

  use LWP::UserAgent;

  my $ua = new LWP::UserAgent;
  $ua->timeout(10);
  $ua->env_proxy;

  WWW::TinySong->ua($ua);

  # customize the service

  WWW::TinySong->service('http://tinysong.com/');

  # tolerate some server errors

  WWW::TinySong->retries(5);

=head1 DESCRIPTION

tinysong.com is a web app that can be queried for a song and returns a tiny
URL, allowing you to listen to the song for free online and share it with
friends.  L<WWW::TinySong> is a Perl interface to this service, allowing you
to programmatically search its underlying database.  (Yes, for those who are
curious, the module currently works by scraping.)

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
our $VERSION   = '0.06';

my($ua, $service, $retries);

=head1 FUNCTIONS

The main functionality is implemented by C<tinysong>.  It may be imported
into your namespace and used as any other function.  The other functions
allow the customization of requests issued by this module.

=over 4

=item tinysong( $QUERY_STRING [, $LIMIT ] )

=item WWW::TinySong->tinysong( $QUERY_STRING [, $LIMIT ] )

Searches tinysong.com for $QUERY_STRING, giving up to $LIMIT results.
$LIMIT defaults to 10 if not C<defined>.  Returns an array in list context
or the top result in scalar context.  Return elements are hashrefs with
keys C<qw(album artist song url)>. Their values will be the empty string if
not given by the website.  Here's a quick script to demonstrate:

  #!/usr/bin/perl

  use WWW::TinySong qw(tinysong);
  use Data::Dumper;

  print Dumper tinysong("a hard day's night", 3);

...and its output on my system at the time of this writing:

  $VAR1 = {
            'album' => 'Beatles',
            'artist' => 'Beatles',
            'song' => 'Hard Day\'s Night',
            'url' => 'http://tinysong.com/2gxh'
          };
  $VAR2 = {
            'album' => '1',
            'artist' => 'The Beatles',
            'song' => 'A Hard Day\'s Night',
            'url' => 'http://tinysong.com/2BI5'
          };
  $VAR3 = {
            'album' => 'A Hard Day\'s Night',
            'artist' => 'The Beatles',
            'song' => 'And I Love Her',
            'url' => 'http://tinysong.com/2i03'
          };

=cut

sub tinysong {
    unshift @_, __PACKAGE__ # add the package name unless already there
        unless defined($_[0]) && UNIVERSAL::isa($_[0], __PACKAGE__);

    my($pkg, $string, $limit) = @_;
    if(wantarray) {
        $limit = 10 unless defined $limit;
    }
    else {
        $limit = 1; # no point in searching for more if only one is needed
    }

    my $service = $pkg->service;

    my $response = $pkg->_get(sprintf('%s?s=%s&limit=%d', $service,
        CGI::escape(lc($string)), $limit));

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
                if(defined($class) && $class =~ /^(?:album|artist|song title)$/i) {
                    $current_class = lc $class;
                    croak 'Unexpected results while parsing HTML'
                        if !@ret || defined($ret[$#ret]->{$current_class});
                }
            }
            elsif($tagname eq 'a' && $attr->{class} eq 'link') {
                my $href = $attr->{href};
                croak 'Bad song link' unless defined $href;
                croak 'Song link doesn\'t seem to match service'
                    unless substr($href, 0, length($service)) eq $service;
                push @ret, {url => $href};
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
    $parser->parse($response->decoded_content || $response->content);
    $parser->eof;

    for my $res (@ret) {
    	$res->{song} = $res->{'song title'};
    	delete $res->{'song title'};
        $res->{$_} ||= '' for qw(album artist song);
        $res->{album}  =~ s/^\s+on\s//;
        $res->{artist} =~ s/^\s+by\s//;
    }

    return wantarray ? @ret : $ret[0];
}

sub _get {
    my($response, $pkg, $url) = (undef, @_);
    for(0..$pkg->retries) {
        $response = $pkg->ua->get($url);
        last if $response->is_success;
        croak $response->message || $response->status_line
            if $response->is_error && $response->code != 500;
    }
    return $response;
}

=item WWW::TinySong->ua( [ $USER_AGENT ] )

Returns the user agent object used by this module for web retrievals, first
setting it to $USER_AGENT if it's specified.  Defaults to a C<new>
L<LWP::UserAgent>.  If you explicitly set this, you don't have to use a
LWP::UserAgent, it may be anything that can C<get> a URL and return a
response object.

=cut

sub ua {
    if($_[1]) {
        $ua = $_[1];
    }
    elsif(!$ua) {
        eval {
            require LWP::UserAgent;
            $ua = new LWP::UserAgent;
        };
        carp 'Problem setting user agent' if $@;
    }
    return $ua;
}

=item WWW::TinySong->service( [ $URL ] )

Returns the web address of the service used by this module, first setting
it to $URL if it's specified.  Defaults to <http://tinysong.com/>.

=cut

sub service {
    return $service = $_[1] ? $_[1] : $service || 'http://tinysong.com/';
}

=item WWW::TinySong->retries( [ $COUNT ] )

Returns the number of consecutive internal server errors the module will ignore
before failing, first setting it to $COUNT if it's specified.  Defaults to 0
(croak, do not retry in case of internal server error).  This was created
because read timeouts seem to be a common problem with the web service.  The
module now provides the option of doing something more useful than immediately
failing.

=cut

sub retries {
    return $retries = $_[1] ? $_[1] : $retries || 0;
}

=back

=cut

1;

__END__

=head1 BE NICE TO THE SERVERS

Please don't abuse the tinysong.com web service.  If you anticipate making
a large number of requests, don't make them too frequently.  There are
several CPAN modules that can help you make sure your code is nice.  Try,
for example, L<LWP::RobotUA> as the user agent:

  use WWW::TinySong qw(tinysong);
  use LWP::RobotUA;

  my $ua = LWP::RobotUA->new('my-nice-robot/0.1', 'me@example.org');

  WWW::TinySong->ua($ua);

  # tinysong() should now be well-behaved

=head1 SEE ALSO

L<http://tinysong.com/>, L<LWP::UserAgent>, L<LWP::RobotUA>

=head1 BUGS

Please report them!  Submit a report at 
L<http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-TinySong>, create an
issue at L<http://elementsofpuzzle.googlecode.com/>, or drop me an e-mail.

=head1 AUTHOR

Miorel-Lucian Palii, E<lt>mlpalii@gmail.comE<gt>

=head1 VERSION

Version 0.06  (June 22, 2009)

The latest version is hosted on Google Code as part of
L<http://elementsofpuzzle.googlecode.com/>.  Significant changes are also
contributed to CPAN: L<http://search.cpan.org/dist/WWW-TinySong/>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Miorel-Lucian Palii

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
