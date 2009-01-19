package WWW::TinySong;

=head1 NAME

WWW::TinySong - Get free music links from tinysong.com

=head1 SYNOPSIS

  # function-oriented

  use WWW::TinySong qw(tinysong);

  for(tinysong("we are the champions")) {
      printf("%s", $_->{song});
      printf(" by %s", $_->{artist}) if $_->{artist};
      printf(" on %s", $_->{album}) if $_->{album};
      printf(" <%s>\n", $_->{url});
  }


  # object-oriented

  use WWW::TinySong;
  
  my $ts = new WWW::TinySong;
  
  $ts->timeout(10); # timeout() is inherited from LWP::UserAgent
  $ts->env_proxy(); # env_proxy() is inherited from LWP::UserAgent

  for($ts->tinysong("we are the champions")) {
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
use LWP::UserAgent;

our @EXPORT_OK = qw(tinysong);
our @ISA       = qw(LWP::UserAgent Exporter);
our $VERSION   = '0.04_03';
$VERSION       = eval $VERSION;

my $default;

=head1 FUNCTIONS / METHODS

This module defines one public function/method. In the function-oriented
approach, it would be called directly. Alternatively, it may be called on
a C<WWW::TinySong> object. See the next section for details.

=over 4

=item tinysong ( QUERY_STRING [, LIMIT ] )

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

=back

=head1 FUNCTION-ORIENTED VS. OBJECT-ORIENTED INTERFACE

The function-oriented interface should be adequate for many users. This
involves just importing what you need into your namespace and calling it
as any other function.

If you need to customize the underlying L<LWP::UserAgent> used for retrievals,
you would use the object-oriented interface: create a L<WWW::TinySong> with
the desired options and call the methods of the resulting object. Note that
L<WWW::TinySong> subclasses L<LWP::UserAgent>, so C<new> accepts the same
arguments, and all L<LWP::UserAgent> methods are supported. You could
even C<bless> an existing L<LWP::UserAgent> as L<WWW::TinySong>, not that
I'm recommending you do that.

The L</SYNOPSIS> demonstrates both ways of using this module.

=cut

sub tinysong {
    my($self, $string, $limit) = _self_or_default(@_);
    if(wantarray) {
        $limit = 10 unless defined $limit;
    }
    else {
        $limit = 1; # no point in searching for more if only one is needed
    }
    
    my $response = $self->get(sprintf('http://tinysong.com/?s=%s&limit=%d',
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

################################################################################

sub _default {
    return $default ||= __PACKAGE__->new;
}

sub _self_or_default {
    if(defined $_[0]) {
        if(ref $_[0]) {
            # first arg defined and ref, put in default unless proper class
            unshift @_, _default() unless UNIVERSAL::isa($_[0], __PACKAGE__);
        }
        else {
            # first arg defined but not ref, replace if class or put in default
            shift if UNIVERSAL::isa($_[0], __PACKAGE__);
            unshift @_, _default();
        }
    }
    else {
        # first arg not defined, put in default
        unshift @_, _default();
    }
    return @_;
}

1;

__END__

=head1 SEE ALSO

L<http://tinysong.com/>, L<LWP::UserAgent>

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
