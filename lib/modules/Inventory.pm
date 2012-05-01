#!/usr/bin/perl -T
#
# Name: Inventory.pm
# Creator: Guy Edwards
# Created: 2008-07-28
# Description: Common functions for the inventory suite
#
package Inventory;
use strict;
use warnings;

=pod

=head1 NAME

Inventory - Networks team inventory module

=head2 VERSION

This document describes Inventory version 1.00

=head1 SYNOPSIS

use Inventory;

=head1 DESCRIPTION

 In the basic Inventory.pm the main abilities are:
  - create a database connection
  - restrict access to authorised users
  - find out if they are a superuser
  - get a hash of GET query string fields

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

A postgres database with the database layout that's expected is required.
Other configuration is at the application level via a configuration file, but
the module is only passed the database handle.

=head1 SUBROUTINES/METHODS

=cut

our $VERSION = '1.00';
use base qw( Exporter);
our @EXPORT_OK = qw(
  dbconnect
  is_superuser
  populate_query_fields
  acl_checker
  abort_ifnofile
);

use DBI;
use DBD::Pg;
use Log::Log4perl;

=pod

=head2 is_superuser

boolean test to see if the user is priviliged superuser according to config file

=cut

sub is_superuser {
    my ( $officer, $config ) = @_;

    my $TRUE = '1';

    return if !defined $officer || length($officer) == 0;

    my @superusers = split m/,/x, $config->{general}->{superusers};
    foreach my $superuser (@superusers) {
        return $TRUE if defined $superuser and ( "$officer" eq "$superuser" );
    }

    return;
}

=pod

=head2 dbconnect

Connects to the database

=cut

sub dbconnect {

    my ( $dbname, $dbuser, $dbhost, $dbpass ) = @_;
    if ( !$dbname ) { print "ERROR: no dbname\n"; return 0; }
    if ( !$dbuser ) { print "ERROR: no dbuser\n"; return 0; }
    if ( !$dbhost ) { print "ERROR: no dbhost\n"; return 0; }
    if ( !$dbpass ) { print "ERROR: no dbpass\n"; return 0; }

    my $dbh = DBI->connect(
        "dbi:Pg:dbname=$dbname;host=$dbhost",
        "$dbuser",
        "$dbpass",
        {
            RaiseError => 0,    ### Dont Report errors via die()
            PrintError => 1     ### Report errors via warn()
        }
    );
    return $dbh;
}

=pod

=head2 populate_query_fields

=cut

sub populate_query_fields {

    # this lets us use %get
    my %query_string;
    my $tmp = $ENV{'QUERY_STRING'};
    my @parts = split m/\&/x, $tmp;

    foreach my $part (@parts) {
        my ( $name, $value ) = split m/\=/x, $part;
        $query_string{"$name"} = $value;
    }
    return (%query_string);
}

=pod

=head2 acl_checker

I differenciate between get and post, not everyone agrees with this but there
is an RFC2616 that suggests that we should. I do so for behaviour not security
reasons.

=cut

sub acl_checker {
    my $tt          = shift;
    my $valid_users = shift;

    if ( !$valid_users ) {
        $tt->process( 'inventory_denied.tt',
            { remote_user => 'Error in application' } );
        $tt->process( 'inventory_footer.tt', {} );
        exit;
    }

    my $allowed     = 'no';
    my $remote_user = $ENV{REMOTE_USER};

    my @valid_users = split m/,/x, "$valid_users";
    foreach (@valid_users) {
        if ( "$remote_user" eq "$_" ) {
            $allowed = 'yes';
        }
    }
    if ( $allowed eq 'no' ) {
        $tt->process( 'inventory_denied.tt', { remote_user => $remote_user, } );
        $tt->process( 'inventory_footer.tt', {} );
        exit;
    }
}

=pod

=head2 abort_ifnofile

Catch a non existant configuration file to avoid messy failure

=cut

sub abort_ifnofile {
    my $test = @_;

    if ( not defined $test or length($test) == 0 ) {
        print
          "INTERNAL ERROR: abort_ifnofile called with no file passed to it.\n";
        exit;
    }

    if ( -r $test ) {
        return 1;
    }

    if ( -e $test ) {
        print
"The needed configuration file \"$test\" exists but isn\'t readable. Aborting\n";
        exit;    # called before file lock so can exit normally
    }
    else {
        print
          "The needed configuration file \"$test\" doesn\'t exist. Aborting\n";
        exit;    # called before file lock so can exit normally
    }
}

1;
__END__

=pod

=head1 DEPENDENCIES

DBI, DBD::Pg

=head1 INCOMPATIBILITIES

none known

=head1 BUGS AND LIMITATIONS

Report any found to <guyjohnedwards@gmail.com>

=head1 AUTHOR

Guy Edwards, maintained by <guyjohnedwards@gmail.com>

=head1 LICENSE AND COPYRIGHT

Network Device Inventory - keep a database of devices to feed other systems
(such as monitoring software). Copyright 2007 University of Oxford

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
Street, Fifth Floor, Boston, MA 02110-1301 USA.

The University of Oxford disclaims all copyright interest in the program
`Inventory' written by Guy Edwards as agreed by Dr. Stuart Lee, Director of
Oxford University Computer Services.

Oliver Gorwits, who in 2008 contributed sections of the hostgroups programming
also disclaims all copyright interest in the program.
