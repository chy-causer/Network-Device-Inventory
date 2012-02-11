#!/usr/bin/perl -T
#
# Name: Manufacturers.pm
# Creator: Guy Edwards
# Created: 2008-08-05
# Description: unknown
#
# $Id: Manufacturers.pm 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: 94iW_9Wkvsoy4xeZCyWPd_vBu_dqgax4JVUjEzBLeALYp $
#
package Inventory::Manufacturers;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_manufacturers
  edit_manufacturers
  get_manufacturers_info
  count_models_permanufacturer
  count_hosts_permanufacturer
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;
use Inventory::Hosts qw(get_hosts_info);

sub create_manufacturers {
    my ( $dbh, $posts ) = @_;
    my %message;

    if (   !exists $posts->{'manufacturer_name'}
        || $posts->{'manufacturer_name'} =~ m/[^\w\s]/x
        || length( $posts->{'manufacturer_name'} ) < 1
        || length( $posts->{'manufacturer_name'} ) > 35 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = 'Input Error: Check your input is alpha numeric';
        return \%message;
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
    my $sth = $dbh->prepare('INSERT INTO manufacturers(name) VALUES(?)');

    if ( !$sth->execute( $posts->{'manufacturer_name'} ) ) {
        $message{'ERROR'} =
          'Internal Error: The manufacturer creation was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'The manufacturer creation was successful';
    return \%message;
}

sub edit_manufacturers {
    my ( $dbh, $posts ) = @_;
    my %message;

    # dump bad inputs
    if (
           !exists $posts->{'manufacturer_id'}
        || $posts->{'manufacturer_id'} =~ m/\D/x
        || length( $posts->{'manufacturer_id'} ) < 1

        || !exists $posts->{'manufacturer_name'}
        || $posts->{'manufacturer_name'} =~ m/[^\w\s]/x
        || length( $posts->{'manufacturer_name'} ) < 1
        || length( $posts->{'manufacturer_name'} ) > 35
      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: One of the supplied inputs was invalid.';
        return \%message;
    }

    my $sth = $dbh->prepare('UPDATE manufacturers SET name=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'manufacturer_name'},
            $posts->{'manufacturer_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The interface edit was unsuccessful.';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your changes were commited successfully';
    return \%message;
}

sub get_manufacturers_info {
    my ( $dbh, $manufacturer_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $manufacturer_id ) {
        $sth = $dbh->prepare(
            'SELECT id,name FROM manufacturers WHERE id=? ORDER BY name');
        return if !$sth->execute($manufacturer_id);
    }
    else {
        $sth = $dbh->prepare('SELECT id,name FROM manufacturers ORDER BY name');
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub count_models_permanufacturer {
    my $dbh = shift;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
        return \%message;
    }

    my $sth;

    # models, in the raw, phoar!
    my @raw_models = Inventory::Models::get_models_info($dbh);

    my %return_hash;

    # cycle through the raw data
    # by model total up models per manf

    foreach (@raw_models) {
        my %dbdata            = %{$_};
        my $manufacturer_name = $dbdata{'manufacturer_name'};
        my $model_name        = $dbdata{'name'};
        my $manufacturer_id   = $dbdata{'manufacturer_id'};

        $return_hash{$manufacturer_id}{'model_total'}++;
        $return_hash{$manufacturer_id}{'model_name'} = $model_name;
        $return_hash{$manufacturer_id}{'manufacturer_name'} =
          $manufacturer_name;
    }
    return \%return_hash;
}

sub count_hosts_permanufacturer {
    my $dbh = shift;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
        return \%message;
    }

    my $sth;

    # hosts, in the... mmm never mind
    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);

    my %return_hash;

    # cycle through the raw data
    # by host total up occurances per manf
    foreach (@raw_hosts) {
        my %dbdata = %{$_};

        my $manufacturer_name = $dbdata{'manufacturer_name'};
        my $manufacturer_id   = $dbdata{'manufacturer_id'};
        my $state             = lc $dbdata{'status_state'};

        # this isn't exactly pretty but it'll work
        $return_hash{$manufacturer_id}{$state}++;
        $return_hash{$manufacturer_id}{'manufacturer_name'} =
          $manufacturer_name;

    }

    return \%return_hash;
}

1;
__END__

=head1 NAME

Inventory::Manufacturers - Information on Manufacturers

=head2 VERSION

This document describes Inventory::Manufacturers version 0.0.1

=head1 SYNOPSIS

  use Inventory::Manufacturers qw(create_manufacturers edit_manufacturers show_manufacturers_info);
  # There are no special setup requirements

=head1 PURPOSE

If you wish to investigate what manufacturers exist in the database or want to
investigate how popular each manufacturer is, then this module assists in that
process. A subroutine is provided for each of: creating, editing, listing all
entries, and listing summary totals of the relationships.

=head1 DESCRIPTION

The module aims to hide the tasks of raw SQL queries to the database from wou
when performing common tasks which involve the relationhips of manufacturers
to models in the inventory table.

The data returned from a query should be generous, as well as the ids of the
hosts involved the names, statuses and similar are returned. Each subroutine
should also give a descriptive success or failure message.

=head2 Main Subroutines

=head3 create_manufacturers($dbh,$hashref)

$dbh is the database handle for the Inventory Database

This subrouting will always return a hashref with the SUCCESS or ERROR state recorded in the hash key and the human description recorded in the hash keys value, e.g.
$message{'SUCCESS'} = 'Your changes were commited successfully';

=head3 edit_manufacturers($dbh,$hashref)
=head3 list_manufacturers_info($dbh,$optional_manufacturersid)
=head3 create_manufacturers($dbh,$hashref)
=head3 count_hosts_permanufacturer($dbh)
=head3 count_models_permanufacturer($dbh)

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected by the overall Inventory module is required. Other configuration is at the application level via a configuration file loaded via Config::Tiny in the calling script, but this module itself is only passed the resulting database handle.

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Inventory;
Inventory::Hosts;
Inventory::Models;

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
