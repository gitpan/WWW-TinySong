package WWW::TinySong;

=head1 NAME

WWW::TinySong - Get free music links using TinySong

=head1 SYNOPSIS

  use WWW::TinySong;

  my $ts = WWW::TinySong->new;
  $ts->timeout(10);
  $ts->env_proxy;

  for($ts->song_search("Never Gonna Give You Up")) {
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
use HTML::Parser;
use LWP::UserAgent;

our @ISA     = qw(LWP::UserAgent);
our $VERSION = '0.00_02';
$VERSION     = eval $VERSION;

=head1 CONSTRUCTOR

L<WWW::TinySong> subclasses L<LWP::UserAgent>, so you can use the same
constructors. If you're lazy, just play with the example given in the
L<SYNOPSIS>: that should be sufficient to get started with this module.

=head1 METHODS

L<WWW::TinySong> implements one more method in addition to the ones
supported by L<LWP::UserAgent>.

=over 4

=item song_search ( QUERY_STRING [, LIMIT ] )

Searches the TinySong database for QUERY_STRING, giving up to LIMIT
results. LIMIT defaults to 10 if unspecified. Method returns an array or
arrayref, depending on context.

=cut

sub song_search {
    my($self, $string, $limit) = @_;
    $limit = 10 unless defined $limit;
    my $query = sprintf("http://tinysong.com?s=%s&limit=%d",
        CGI::escape(lc($string)), $limit);
    my $response = $self->get($query);
    unless($response->is_success) {
        croak $response->status_line;
    }
    else {
        my @ret           = ();
        my $inside_list   = 0;
        my $current_class = undef;
        my $start_h       = sub {
            my($tagname, $attr) = @_;
            if(   lc($tagname) eq 'ul'
               && defined($attr->{id})
               && lc($attr->{id}) eq 'results')
            {
                $inside_list = 1;
                return;
            }
            elsif($inside_list) {
                if(lc($tagname) eq 'span') {
                    my $class = lc($attr->{class});
                    if(   defined($class)
                       && $class =~ /^(?:song|artist|album)$/i)
                    {
                        $current_class = $class;
                        if(!@ret || defined($ret[$#ret]->{$current_class})) {
                            croak "Unexpected results while parsing HTML";
                        }
                    }
                }
                elsif(lc($tagname) eq 'a') {
                    push @ret, { url => $attr->{href} || '' };
                }
            }
        };
        my $text_h        = sub {
            return unless $inside_list && $current_class;
            my $text = shift;
            $ret[$#ret]->{$current_class} = $text;
            undef $current_class;
        };
        my $end_h         = sub {
            return unless $inside_list;
            my $tagname = shift;
            if(lc($tagname) eq 'ul') {
                $inside_list = 0;
            }
            elsif(lc($tagname) eq 'span') {
                undef $current_class;
            }
        };
        my $parser = HTML::Parser->new(
            api_version     => 3,
            start_h         => [ $start_h, "tagname, attr" ],
            text_h          => [ $text_h, "text" ],
            end_h           => [ $end_h, "tagname" ],
            marked_sections => 1,
        );
        $parser->parse($response->decoded_content);
        $parser->eof;
        for my $res (@ret) {
            $res->{$_} ||= '' for qw(album artist song);
            $res->{album}  =~ s/^\s+on\s//;
            $res->{artist} =~ s/^\s+by\s//;
        }
        return wantarray ? @ret : \@ret;
    }
}

=back

=cut

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
