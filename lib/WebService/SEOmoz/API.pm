package WebService::SEOmoz::API;

BEGIN {
    $WebService::SEOmoz::API::VERSION = '0.02';
}

# ABSTRACT: SEOmoz API

use strict;
use warnings;
use LWP::UserAgent;
use URI::Escape qw/uri_escape/;
use Digest::SHA;
use JSON::Any;
use vars qw/$errstr/;

sub new {
    my $class = shift;
    my $args = scalar @_ % 2 ? shift : {@_};

    $args->{accessID}  or do { $errstr = 'accessID is required';  return; };
    $args->{secretKey} or do { $errstr = 'secretKey is required'; return; };

    $args->{expiresInterval} ||= 300;

    # we won't have space before/after accessID/secretKey
    $args->{accessID}  =~ s/(^\s+|\s+$)//g;
    $args->{secretKey} =~ s/(^\s+|\s+$)//g;

    unless ( $args->{ua} ) {
        my $ua_args = delete $args->{ua_args} || { timeout => 120 };
        $args->{ua} = LWP::UserAgent->new(%$ua_args);
    }
    unless ( $args->{json} ) {
        $args->{json} = JSON::Any->new;
    }

    bless $args, $class;
}

sub errstr { $errstr }

sub getAuthenticationStr {
    my ($self) = @_;

    my $expires      = time() + $self->{expiresInterval};
    my $stringToSign = $self->{accessID} . "\n" . $expires;

#    my $binarySignature = Digest::SHA::hmac_sha1($stringToSign, $self->{secretKey});
# We need to base64-encode it and then url-encode that.
#    my $urlSafeSignature = uri_escape(encode_base64($binarySignature));

    # no idea why we need append '%3D'
    my $urlSafeSignature =
      uri_escape(
        Digest::SHA::hmac_sha1_base64( $stringToSign, $self->{secretKey} ) )
      . '%3D';
    my $authenticationStr =
        "AccessID="
      . $self->{accessID}
      . "&Expires="
      . $expires
      . "&Signature="
      . $urlSafeSignature;

    return $authenticationStr;
}

sub makeRequest {
    my ( $self, $url ) = @_;

    #    print STDERR "# get $url\n";

    undef $errstr;

    my $resp = $self->{ua}->get($url);
    unless ( $resp->is_success ) {
        $errstr = $resp->status_line;
        return;
    }

    return $self->{json}->jsonToObj( $resp->content );
}

sub getUrlMetrics {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : {@_};

    my $objectURL = $args->{objectURL}
      or do { $errstr = 'objectURL is required'; return; };
    my $urlToFetch =
        "http://lsapi.seomoz.com/linkscape/url-metrics/"
      . uri_escape($objectURL) . "?"
      . $self->getAuthenticationStr();

    foreach my $k ('Cols') {
        if ( defined $args->{$k} ) {
            $urlToFetch .= "&" . "$k=" . $args->{$k};
        }
    }

    return $self->makeRequest($urlToFetch);
}

sub getLinks {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : {@_};

    my $objectURL = $args->{objectURL}
      or do { $errstr = 'objectURL is required'; return; };
    my $urlToFetch =
        "http://lsapi.seomoz.com/linkscape/links/"
      . uri_escape($objectURL) . "?"
      . $self->getAuthenticationStr();

    foreach my $k (
        'Scope',      'Filter',   'Sort',   'SourceCols',
        'TargetCols', 'LinkCols', 'Offset', 'Limit'
      )
    {
        if ( defined $args->{$k} ) {
            $urlToFetch .= "&" . "$k=" . $args->{$k};
        }
    }

    return $self->makeRequest($urlToFetch);
}

sub getAnchorText {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : {@_};

    my $objectURL = $args->{objectURL}
      or do { $errstr = 'objectURL is required'; return; };
    my $urlToFetch =
        "http://lsapi.seomoz.com/linkscape/anchor-text/"
      . uri_escape($objectURL) . "?"
      . $self->getAuthenticationStr();

    foreach my $k ( 'Scope', 'Sort', 'Cols', 'Offset', 'Limit' ) {
        if ( defined $args->{$k} ) {
            $urlToFetch .= "&" . "$k=" . $args->{$k};
        }
    }

    return $self->makeRequest($urlToFetch);
}

1;

__END__

=pod

=head1 NAME

WebService::SEOmoz::API - SEOmoz API

=head1 VERSION

version 0.02

=head1 SYNOPSIS

    use WebService::SEOmoz::API;

    my $seomoz = WebService::SEOmoz::API->new(
        accessID   => $accessID,
        secretKey  => $secretKey,
        expiresInterval => $expiresInterval, # optional, default 300s
    ) or die "Can't init the seomoz instance: " . $WebService::SEOmoz::API::errstr;
    
    my $t = $seomoz->getUrlMetrics( {
        objectURL => 'www.seomoz.org/blog',
    } ) or die $seomoz->errstr;
    
    $t = $seomoz->getLinks( {
        objectURL => 'www.google.com',
        Scope => 'page_to_page',
        Sort  => 'page_authority',
        Limit => 1,
    } ) or die $seomoz->errstr;

=head1 DESCRIPTION

L<http://www.seomoz.org/api>

=head2 METHODS

=head3 CONSTRUCTION

    my $seomoz = WebService::SEOmoz::API->new(
        accessID   => $accessID,
        secretKey  => $secretKey,
        expiresInterval => $expiresInterval, # optional, default 300s
    );

=over 4

=item * accessID

=item * secretKey

get them from http://www.seomoz.org/api/ after signup

=item * ua_args

passed to LWP::UserAgent

=item * ua

L<LWP::UserAgent> or L<WWW::Mechanize> instance

=back

=head3 getUrlMetrics

    my $t = $seomoz->getUrlMetrics( {
        objectURL => 'www.seomoz.org/blog',
    } );

L<http://apiwiki.seomoz.org/w/page/13991153/URL-Metrics-API>

=head3 getLinks

    my $t = $seomoz->getLinks( {
        objectURL => 'www.google.com',
        Scope => 'page_to_page',
        Filter => 'internal 301',
        Sort => 'page_authority',
        SourceCols => 536870916,
        TargetCols => 4,
        Limit => 1,
    } );

L<http://apiwiki.seomoz.org/w/page/13991141/Links-API>

=head3 getAnchorText

    my $t = $seomoz->getAnchorText( {
        objectURL => 'www.google.com',
        Scope => 'page_to_page',
        Sort => 'page_authority',
        Cols => 536870916,
        Offset => 4,
        Limit => 1,
    } );

L<http://apiwiki.seomoz.org/w/page/13991127/Anchor-Text-API>

=head1 AUTHOR

Fayland Lam <fayland@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Fayland Lam.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
