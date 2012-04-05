#!/opt/perl514/bin/perl

=pod

=head1 NAME

website.t

=head1 SYNOPSIS

prove website.t

=head1 DESCRIPTION

Website testing for the inventory. Note that this will only work for a site in
demo mode as any authentication will stop the external w3c test from being
able to connect.

=head1 METHODS

none

=cut

use strict;

use warnings;
use diagnostics;
use feature ':5.11';
use feature qw{ switch };

our $VERSION = '1.0.0';

use Carp;
use Data::Dumper;
use HTML::Strip;
use LWP::Simple;
use LWP::UserAgent;                      # basic web client
use Text::Aspell;
use Time::HiRes;
use WebService::Validator::HTML::W3C;    # validation
use WebService::Validator::CSS::W3C;
use WWW::Mechanize;
use XML::LibXML;

use Test::More tests => 29;
my $SITENAME    = 'inventory.donder.co.uk';
my $SITEURL     = "http://$SITENAME";
my $SPLASH      = "$SITEURL/index";
my $CSSURL      = "$SITEURL/stylesheet.css";
my $SITEMAP     = "$SITEURL/sitemap.xml";
my $SPELLING_FP = 0;                           # total spelling false positives

=head1 TESTS

=head2 Is the website reachable

Create test to check the site is up. If this fails, probably everythign else
will fail too.

=cut

my $ua       = LWP::UserAgent->new;
my $response = $ua->get("$SPLASH");
ok( $response->is_success, "Sucessful request to $SPLASH" );

=head2 Is the website valid HTML 

A test for valid XHTML, beware of accidentally DOs'ing the W3C service

=cut

my $validate = WebService::Validator::HTML::W3C->new( detailed => 1 );
ok( $validate->validate("$SPLASH"), "Site is valid HTML at $SPLASH" );

=head2 Is the website valid CSS

Create test for valid CSS, again this uses the W3C service so be wary of
testing too often if automated.

This test is limited to the CSS3 valid stylesheet, with as yet unstanradised
CSS moved to its own css file. The test still has value - we're checking for
mistakes.

=cut

ok ( is_valid_css($CSSURL), "Validate CSS at $CSSURL"  );

=head2 Is the spelling correct

Automatically check spelling on the site and alert if the total found mistakes
is higher than the usual number of false positives.

=cut

my @spelling_mistakes = check_spelling($SPLASH);
if ( scalar @spelling_mistakes > $SPELLING_FP ) {
    Carp::carp "Number of spelling errors is " . scalar @spelling_mistakes;
    Carp::carp Dumper \@spelling_mistakes;
}

ok( scalar @spelling_mistakes <= $SPELLING_FP, 'Site spelling is correct' );

=head2 Check the sitemap exists

Create test that the site map exists

=cut

#my $sitemap_ua       = LWP::UserAgent->new;
#my $sitemap_response = $sitemap_ua->get("$SITEMAP");
#ok( $sitemap_response->is_success, 'Sitemap is retreiveable' );

=pod

=head2 Link test the index page

check each link is valid

=cut

my @linktestpages = ( $SPLASH, $SITEMAP );

foreach my $page (@linktestpages) {

    # get the links on the page
    my @links = clean_links( $SITEURL, $page );

    # then test each link
    foreach my $link (@links) {

        # foreach link return undef if deadlink
        my $mech2 = WWW::Mechanize->new();
        my $islive = eval { $mech2->get($link) };

        is( defined $islive, 1, "Link $link at $page is retrievable" );
    }
}

=pod

=head2 check the alt tags have content

=cut

my $imgmech = WWW::Mechanize->new();
$imgmech->get($SPLASH);

# all images with empty alt tags, e.g. alt=""
my @badimages = $imgmech->find_all_images( alt => '' );

is( scalar @badimages, 0, "Test for images with empty alt tags on $SPLASH" );

=pod

=head2 basic test for download size and speed

=cut

my @performance = ( $SPLASH, $SITEMAP, $CSSURL );

my $counter = 0;
foreach my $testpage (@performance) {
    $counter++;
    my $localstore = "/tmp/$counter";

    # time the download
    my $start_time = [Time::HiRes::gettimeofday];
    LWP::Simple::getstore( $testpage, $localstore );
    my $end_time = [Time::HiRes::gettimeofday];
    my $elapsed = Time::HiRes::tv_interval( $start_time, $end_time );

    # get the size outside the timing section
    my $filesize = -s $localstore;

    ok( $filesize < 15_000, "Page size of $testpage is less than 15k" );
    ok( $elapsed < 2.0, "Page download of $testpage took less than 2 seconds" );
}

=head1 SUBROUTINES

=cut

sub check_spelling {
    my $page           = shift;
    my $spell_ua       = LWP::UserAgent->new;
    my $spell_response = $spell_ua->get("$page");
    my $stripped       = HTML::Strip->new();
    my $speller        = Text::Aspell->new or Carp::croak;
    my @text           = split m/\W/x,
      $stripped->parse( $spell_response->decoded_content() );
    $stripped->eof;
    $speller->set_option( 'lang', 'en_GB' );
    my @techwords =
      qw(DWML CSS JQuery Intercap Pyranometer WX Vaisala hoverbox irradiance donder uk http);

    foreach my $localword (@techwords) {
        $speller->add_to_session($localword);
    }

    my @feedback;

    foreach my $word (@text) {
        if (
            length $word < 1    # protect against weirdness
            || $word =~ m/^\d*$/x        # number
            || $word =~ m/^[\d\s]*$/x    # number
          )
        {
            next;
        }

        if ( $speller->check($word) ) {
            next;
        }

        if ( defined $speller->errstr ) {
            my $mistake = $speller->errstr;

            # select the first 4 suggestions
            my @suggestions = ( $speller->suggest($word) )[ 0 .. 3 ];
            push @feedback,
"'$word' maybe a spelling mistake - perhaps try one of @suggestions\n\n";
        }
    }

    return @feedback;
}

sub is_valid_css {
    my $url          = shift;
    my $css_ua       = LWP::UserAgent->new;
    my $css_response = $css_ua->get("$CSSURL");
    my $cssval       = WebService::Validator::CSS::W3C->new;

    my $result =
      eval { $cssval->validate( string => $css_response->decoded_content ) };
    if ( scalar $cssval->errors > 0 ) {
        Carp::carp Dumper $cssval->errors;
        return $result;
    }

    return $result;
}

sub clean_links {
    my $site_url = shift;
    my $page     = shift;
    my %s_url;
    my @clean;

    my $mech = WWW::Mechanize->new();
    $mech->get($page);
    my @raw = $mech->find_all_links();

    # de-duplicate the array objects
    foreach my $entry (@raw) {
        $s_url{ $entry->url } = 1;
    }

    foreach my $s_link ( keys %s_url ) {

        # fix relative links
        given ($s_link) {
            when ( $s_link =~ m/^http/x ) { }
            when ( $s_link =~ m/^[a-zA-Z0-9]/x ) {
                $s_link = "$site_url/$s_link";
            }
            when ( $s_link =~ m/^\//x ) { $s_link = $site_url . $s_link; }
            when ( $s_link =~ m/^#/x )  { $s_link = $page . $s_link; }
        }

        push @clean, $s_link;

    }

    return @clean;
}

=pod

=head1 SEE ALSO

L<Weather::Server>.

=head1 COPYRIGHT

Copyright 2011 Guy Edwards

=cut

