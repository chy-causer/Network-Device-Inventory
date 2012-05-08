#!/usr/bin/perl -T

use warnings FATAL => 'all';
use strict;
our $VERSION = '1.00';

use Carp;
use CGI;
use Config::Tiny;
use Template;

use Inventory 1.0;

my $BASEURL      = CGI::url( -base      => 1 );
my $pagename     = CGI::url( -relative  => 1 );
my $pagelocation = CGI::url( -path_info => 1 );
my $HOSTNAME     = $BASEURL;
my $DIRECTORY    = $pagelocation;
$DIRECTORY =~ s/$pagename//x;

# remove everything from the first . onwards
$HOSTNAME =~ s/\..*$//gx;

# # # remove everything from the start to the last /
$HOSTNAME =~ s/^.*\///gx;

my $CONFIG      = Config::Tiny->new();
my $CONFIG_FILE = "/srv/www/$HOSTNAME/lib/inventory.ini";
$CONFIG = Config::Tiny->read("$CONFIG_FILE");

my $valid_users       = $CONFIG->{'general'}->{allowed_users};
my $htmltemplatepath  = $CONFIG->{'locations'}->{tt_dir};
my $localtemplatepath = $CONFIG->{'locations'}->{local_tt_dir};
my $logconfigfile     = $CONFIG->{'locations'}->{log_conf};

my $q = CGI->new();
print $q->header();

# this just loads the default site settings
my $tt = Template->new(
    { INCLUDE_PATH => [ $localtemplatepath, $htmltemplatepath ] } );

# invalid users get no further than the next line
if ( !exists $CONFIG->{general}->{demo} ) {
    Inventory::acl_checker( $tt, $valid_users );
}

$tt->process( 'inventory_javascript_hosts.tt', { 
        baseurl   => $BASEURL,
        directory => $DIRECTORY,
      } )
  || Carp::croak "Error: can't load the page due to " . $tt->error() . "\n";

