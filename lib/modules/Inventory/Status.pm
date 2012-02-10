#!/usr/bin/perl -T
#
# Name: Status.pm
# Creator: Guy Edwards
# Created: 2008-08-05
# Description: unknown
#
# $Id: Status.pm 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: HZMufh3PNOshkQLwmQB0nIxlKrR3JUTNqHCMVU4JGQ9Jr $
#
package Inventory::Status;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_status
  edit_status
  get_status_info
  count_states
);

use DBI;
use DBD::Pg;
use Inventory::Hosts qw(get_hosts_info);

sub create_status {
    my ( $dbh, $posts ) = @_;
    my %message;

    if (  !exists $posts->{'status_state'}
        || length( $posts->{'status_state'} ) < 1
        || length( $posts->{'status_state'} ) > 25
        || $posts->{'status_state'} =~ m/[^\w\s]/x )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = 'Input Error: Check your input is alpha numeric.';
        return \%message;
    }

    if ( exists $posts->{'status_description'} ) {
        $posts->{'status_description'} =~ s/[^\w\s]//gx;
        $posts->{'status_description'} = substr $posts->{'status_description'},
          0, 254;
    }
    else {
        $posts->{'status_description'} = 'none';
    }

    my $sth =
      $dbh->prepare('INSERT INTO status(state,description) VALUES(?,?)');

    if (
        !$sth->execute(
            $posts->{'status_state'},
            $posts->{'status_description'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The status creation was unsuccessful.';
        return \%message;
    }

    $message{'SUCCESS'} = 'The status creation was successful.';
    return \%message;
}

sub edit_status {
    my ( $dbh, $posts ) = @_;
    my %message;

    if (
          !exists $posts->{'status_state'}
        || length( $posts->{'status_state'} ) < 1
        || length( $posts->{'status_state'} ) > 25
        || $posts->{'status_state'} =~ m/[^\w\s]/x

        || !exists $posts->{'status_id'}
        || length( $posts->{'status_id'} ) < 1
        || $posts->{'status_id'} =~ m/\D/x
      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = 'Input Error: Check your input is alpha numeric.';
        return \%message;
    }

    if ( exists $posts->{'status_description'} ) {
        $posts->{'status_description'} =~ s/[^\w\s]//gx;
        $posts->{'status_description'} = substr $posts->{'status_description'},
          0, 254;
    }
    else {
        $posts->{'status_description'} = "none";
    }

    my $sth =
      $dbh->prepare('UPDATE status SET state=?,description=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'status_state'}, $posts->{'status_description'},
            $posts->{'status_id'}
        )
      )
    {
        $message{'ERROR'} = 'Internal Error: The status edit was unsuccessful.';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your status changes were commited successfully';
    return \%message;
}

sub get_status_info {
    my $dbh       = shift;
    my $status_id = shift;
    my $sth;

    return if !defined $dbh;

    if ( defined $status_id ) {
        $sth = $dbh->prepare(
            'SELECT id,state,description FROM status WHERE id=? ORDER BY state'
        );
        return if !$sth->execute($status_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT id,state,description FROM status ORDER BY state');
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub count_states {
    my $dbh = shift;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
        return \%message;
    }

    my $sth;
    my @raw_data = Inventory::Hosts::get_hosts_info($dbh);
    my %return_hash;

    # cycle through the raw data
    # by group total up states
    foreach (@raw_data) {
        my %dbdata = %{$_};
        my $state  = $dbdata{'status_state'};

        # this isn't exactly pretty but it'll work
        $return_hash{$state}++;
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
