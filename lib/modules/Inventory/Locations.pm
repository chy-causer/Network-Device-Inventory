#!/usr/bin/perl -T
#
# Name: Locations.pm
# Creator: Guy Edwards
# Created: 2008-08-05
# Description: unknown
#
# $Id: Locations.pm 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: E9_XxmQUp2xoEGQClDmg9VkdPctUC_unBsjUwq7rI7j89 $
#
package Inventory::Locations;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
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
use Inventory::Hosts qw(get_hosts_info);

sub create_locations {
    my ( $dbh, $posts ) = @_;
    my %message;

    if (   !exists $posts->{'location_name'}
        || $posts->{'location_name'} =~ m/[^\w\s\-\(\)\:]/x
        || length( $posts->{'location_name'} ) < 1
        || length( $posts->{'location_name'} ) > 55 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = "Input Error: Check your input is alpha numeric";
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

    # dump bad inputs
    if (
        !exists $posts->{'location_id'}
        || $posts->{'location_id'} =~ m/\D/x

        || !exists $posts->{'location_name'}
        || $posts->{'location_name'} =~ m/[^\w\s\-\(\)\:]/x
        || length( $posts->{'location_name'} ) < 1
        || length( $posts->{'location_name'} ) > 55
      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          "Input Error: One of the supplied inputs was invalid.";
        return \%message;
    }

    $posts->{'location_name'} = $posts->{'location_name'};

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
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
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

1;
__END__

=head1 NAME

Inventory - Networks team inventory module

=head2 VERSION

This document describes Inventory version 0.0.1

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

 All creates and edits return a hash, the key gives success or failure, the value gives the human message of what went wrong.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected is required. Other configuration is at the application level via a configuration file, but the module is only passed the database handle.

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



(c) Guy Edwards