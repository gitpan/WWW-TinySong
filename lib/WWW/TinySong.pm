package WWW::TinySong;

=head1 NAME

WWW::TinySong - Get free music links using TinySong

=head1 SYNOPSIS

  # functional 

  use WWW::TinySong qw(tinysong);

  for(tinysong("never gonna give you up")) {
      printf("%s", $_->{song});
      printf(" by %s", $_->{artist}) if $_->{artist};
      printf(" on %s", $_->{album}) if $_->{album};
      printf(" <%s>\n", $_->{url});
  }


  # object-oriented

  use WWW::TinySong;
  
  my $ts = new WWW::TinySong;
  
  $ts->timeout(10);
  $ts->env_proxy();

  for($ts->tinysong("never gonna give you up")) {
      printf("%s", $_->{song});
      printf(" by %s", $_->{artist}) if $_->{artist};
      printf(" on %s", $_->{album}) if $_->{album};
      printf(" <%s>\n", $_->{url});
  }

=head1 DESCRIPTION

TinySong is a web app that can be queried for a song and returns a tiny
URL, allowing you to listen to the song for free online and share it with
friends. L<WWW::TinySong> is a Perl interface to this service, allowing you
to programmatically search its underlying database.

=cut

use 5.008;
use strict;
use warnings;

use Carp;
use CGI;
use Exporter;
use HTML::Parser;
use LWP::UserAgent;

our @EXPORT_OK = qw(tinysong);
our @ISA       = qw(LWP::UserAgent Exporter);
our $VERSION   = '0.03';

my $default;

=head1 FUNCTIONAL INTERFACE

The functional interface should be adequate for most users. If you need
to customize the L<LWP::UserAgent> used for the underlying retrievals,
take a look at the object-oriented interface.

=over 4

=item tinysong ( QUERY_STRING [, LIMIT ] )

Searches the TinySong database for QUERY_STRING, giving up to LIMIT
results. LIMIT defaults to 10 if not C<defined>. Returns an array in list
context or the top result in scalar context. Return elements are hashrefs
with keys C<qw(album artist song url)>. Their values will be the empty
string if not given by the website. Here's a quick script to
demonstrate:

  #!/usr/bin/perl

  use WWW::TinySong qw(tinysong);
  use Data::Dumper;
   
  print Dumper tinysong("a hard day's night", 3);

...and its output on my system at the time of this writing:

  $VAR1 = {
            'album' => 'Golden Beatles',
            'artist' => 'The Beatles',
            'song' => 'A Hard Day\'s Night',
            'url' => 'http://tinysong.com/2Cqe'
          };
  $VAR2 = {
            'album' => '',
            'artist' => 'The Beatles',
            'song' => 'A Hard Day\'s Night',
            'url' => 'http://tinysong.com/2BI5'
          };
  $VAR3 = {
            'album' => 'The Beatles 1',
            'artist' => 'The Beatles',
            'song' => 'A Hard Day\'s Night',
            'url' => 'http://tinysong.com/2Cqi'
          };

=back

=head1 OBJECT-ORIENTED INTERFACE

=head2 CONSTRUCTORS

L<WWW::TinySong> subclasses L<LWP::UserAgent>, so you can use the same
constructors. You could even C<bless> an existing L<LWP::UserAgent> as
L<WWW::TinySong>, not that I'm recommending you do that.

=head2 METHODS

L<WWW::TinySong> implements one more method in addition to the ones
supported by L<LWP::UserAgent>.

=over 4

=item tinysong ( QUERY_STRING [, LIMIT ] )

Does exactly the same thing as the functional version (see above).

=back

=cut

sub tinysong {
    my($self, $string, $limit) = _self_or_default(@_);
    if(wantarray) {
        $limit = 10 unless defined $limit;
    }
    else {
        $limit = 1; # no point in searching for more if only one is needed
    }
    
    my $query = sprintf('http://tinysong.com?s=%s&limit=%d',
        CGI::escape(lc($string)), $limit);
    my $response = $self->get($query);
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
                if(defined($class) && $class =~ /^(?:song|artist|album)$/i) {
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
    $parser->parse($response->decoded_content);
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

Please report them.

=head1 AUTHOR

Miorel-Lucian Palii, E<lt>mlpalii@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Miorel-Lucian Palii

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
