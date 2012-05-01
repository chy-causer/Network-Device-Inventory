package Inventory::Locations;
use strict;
use warnings;

our $VERSION = '1.00';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_locations
  edit_locations
  get_locations_info
  count_locations_perhost
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;
use Inventory::Hosts 1.0;

sub create_locations {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} = 'Internal Error: lost database connectivity';
        return \%message;
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
    my $sth = $dbh->prepare('INSERT INTO locations(name) VALUES(?)');

    if ( !$sth->execute( $posts->{'location_name'} ) ) {
        $message{'ERROR'} =
          "Internal Error: The location creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = "The location creation was successful";
    return \%message;
}

sub edit_locations {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} = 'Internal Error: lost database connectivity';
        return \%message;
    }

    my $sth = $dbh->prepare('UPDATE locations SET name=? WHERE id=?');
    if ( !$sth->execute( $posts->{'location_name'}, $posts->{'location_id'} ) )
    {
        $message{'ERROR'} =
          "Internal Error: The interface edit was unsuccessful.";
        return \%message;
    }

    $message{'SUCCESS'} = "Your changes were commited successfully";
    return \%message;
}

sub get_locations_info {
    my ( $dbh, $location_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $location_id ) {
        $sth = $dbh->prepare(
            'SELECT id,name FROM locations WHERE id=? ORDER BY name');
        return if !$sth->execute($location_id);
    }
    else {
        $sth = $dbh->prepare('SELECT id,name FROM locations ORDER BY name');
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub count_locations_perhost {
    my $dbh = shift;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} = 'Internal Error: lost database connectivity';
        return \%message;
    }

    my $sth;

    # hosts, in the raw, phoar!
    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);
    my %return_hash;

    # cycle through the raw data
    foreach (@raw_hosts) {
        my %dbdata        = %{$_};
        my $location_name = $dbdata{'location_name'};
        my $location_id   = $dbdata{'location_id'};

        my $state = lc $dbdata{'status_state'};
        $return_hash{$location_id}{$state}++;
        $return_hash{$location_id}{'location_name'} = $location_name;
    }
    return \%return_hash;
}

sub delete_locations {

    # delete a single location

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM locations WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
"Internal Error: The location could not be deleted, it's probably in use by a host entry";
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';

    return \%message;
}

1;
__END__

=head1 NAME

Locations.pm

=head2 VERSION

This document describes Inventory version 1.00

=head1 SYNOPSIS

  use Inventory;

=head1 DESCRIPTION

=head2 Main Subroutines

The main abilities are:
  - create new types of entry in a table
  - edit existing entries in a table
  - list existing entries

=head2 Returns
All returns from lists are arrays of hashes

All creates and edits return a hash, the key gives success or failure, the
value gives the human message of what went wrong.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected is required.
Other configuration is at the application level via a configuration file, but
the module is only passed the database handle.

=head1 DEPENDENCIES

Since I'm talking to a postgres database
DBI
DBD::Pg

...and for sanity/consistency...
Regexp::Common


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

The University of Oxford agrees to the release under the GPL of in the program
`Inventory' written by Guy Edwards as agreed by Dr. Stuart Lee, Director of
Oxford University Computer Services.

Oliver Gorwits, who in 2008 contributed sections of the hostgroups programming
also agreed to the code release under the GPL.
