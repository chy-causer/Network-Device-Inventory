#!/usr/bin/perl -T
#
# Name: bashrc
# Creator: Guy Edwards
# Created: 2008-09-09
# Description: bashrc style output for groups
#
# $Id: bashrc 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: rSA0zyWEI5krA_ppu0Xd1VEhEsLB09hecpu4fS8q9dO2o $
#

use warnings FATAL => 'all';
use strict;

use CGI;
use Template;
use Config::Tiny;
use DBI;
use DBD::Pg;

use Inventory qw(dbconnect populate_query_fields acl_checker);
use Inventory::Introlemembers qw(fqdns_bybashgroup);

my $HOSTNAME = CGI::url( -base => 1 );

# remove everything from the first . onwards
$HOSTNAME =~ s/\..*$//gx;

# # # remove everything from the start to the last /
$HOSTNAME =~ s/^.*\///gx;

my $CONFIG      = Config::Tiny->new();
my $CONFIG_FILE = "/srv/www/$HOSTNAME/lib/inventory.ini";
$CONFIG = Config::Tiny->read("$CONFIG_FILE");

my $dbhost           = $CONFIG->{'database'}->{db_host};
my $dbname           = $CONFIG->{'database'}->{db_name};
my $dbuser           = $CONFIG->{'database'}->{db_user};
my $dbpass           = $CONFIG->{'database'}->{db_pass};
my $dbh              = dbconnect( $dbname, $dbuser, $dbhost, $dbpass );
my $valid_users      = $CONFIG->{'general'}->{allowed_users};
my $htmltemplatepath = $CONFIG->{'locations'}->{tt_dir};

#############################################################################
#                                     main                                  #
#############################################################################

my $q = CGI->new();
print $q->header();

# this just loads the default site settings
my $tt = Template->new( { INCLUDE_PATH => $htmltemplatepath, } );

# invalid users get no further than the next line
Inventory::acl_checker( $tt, $valid_users );

my %fqdns_bybashgroups =
  %{ Inventory::Introlemembers::fqdns_bybashgroup($dbh) };

$tt->process( 'inventory_bashrc.tt',
    { fqdns_bybashgroups => \%fqdns_bybashgroups, } );

__END__

=head1 NAME
bashrc

=head1 VERSION

This documentation refers to  version 

=head1 USAGE

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 DESCRIPTION

=head1 DIAGNOSTICS

error messages

=head1 CONFIGURATION

configuration via /srv/www/$HOSTNAME/lib/inventory.ini

where $HOSTNMAE is the name of the web host the page is being served from (e.g. 'comms')

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

none known

=head1 BUGS AND LIMITATIONS

Report any found to <hostmaster@ox.ac.uk>

=head1 AUTHOR

Guy Edwards, maintained by <hostmaster@ox.ac.uk>

=head1 LICENSE AND COPYRIGHT



(c) University of Oxford
