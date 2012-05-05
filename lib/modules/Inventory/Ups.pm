package Inventory::Ups;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Ups

=head2 VERSION

This document describes Inventory::Ups version 1.01

=head1 SYNOPSIS

  use Inventory::Ups;

=head1 DESCRIPTION

Module to handle the data relating to UPS protection relationships.

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_ups
  delete_ups
  edit_ups
  get_ups_info
  get_links_info
  ups_byhostid
  host_byupsid
);

use DBI;
use DBD::Pg;
use Inventory::Hosts 1.0;
use Inventory::Introles 1.0;

my $ENTRY          = 'ups to host link';
my $MSG_DBH_ERR    = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR  = 'Input Error: Please check your input';
my $MSG_CREATE_OK  = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK    = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR   = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK  = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR  = 'The error was fatal, processing stopped';

=pod

=head2 Main Subroutines

=cut

sub create_ups {
    my ( $dbh, $posts ) = @_;

    my %message;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (
           !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1

        || !exists $posts->{'ups_id'}
        || $posts->{'ups_id'} =~ m/\D/x
        || length( $posts->{'ups_id'} ) < 1
      )
    {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    my $sth = $dbh->prepare(
        'INSERT INTO hosts_to_upshost (host_id,ups_id) VALUES(?,?)');

    if ( !$sth->execute( $posts->{'host_id'}, $posts->{'ups_id'} ) ) {

        # find out what the error was
        my $full_error_string = $dbh->errstr;
        my $duplicate_entry_message =
          'duplicate key violates unique constraint';
        if ( $full_error_string =~ m/$duplicate_entry_message/ix ) {
            $message{'ERROR'} =
'Internal Error: You just tried to add a host to a ups that it is already a linked with.';
        }
        else {
            return { 'ERROR' => $MSG_CREATE_ERR };
        }
        return \%message;
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

sub delete_ups {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM hosts_to_upshost WHERE id=?');
    if ( !$sth->execute($link_id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

sub edit_ups {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    # dump bad inputs
    if (
           !exists $posts->{'link_id'}
        || $posts->{'link_id'} =~ m/\D/x
        || length $posts->{'link_id'} < 1

        || !exists $posts->{'ups_id'}
        || $posts->{'ups_id'} =~ m/\D/x
        || length $posts->{'ups_id'} < 1

        || !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length $posts->{'host_id'} < 1

      )
    {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    my $sth = $dbh->prepare(
        'UPDATE hosts_to_upshost SET host_id=?,ups_id=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'ups_id'}, $posts->{'link_id'}
        )
      )
    {

        # find out what the error was
        my $full_error_string = $dbh->errstr;
        my $duplicate_entry_message =
          'duplicate key violates unique constraint';
        if ( $full_error_string =~ m/$duplicate_entry_message/ix ) {
            $message{'ERROR'} =
'Input Error: You just tried to link a host to a ups that it is already linked with.';
        }
        else {
            return { 'ERROR' => $MSG_EDIT_ERR };
        }
        return \%message;
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

sub ups_byhostid {
    my ( $dbh, $host_id ) = @_;

    return if !$dbh;
    return if !$host_id;

    my $sth =
      $dbh->prepare( "SELECT"
          . " hosts_to_upshost.id as link_id,"
          . " hosts_to_upshost.ups_id,"
          . " hosts.name AS ups_name "
          . "FROM hosts_to_upshost,hosts "
          . "WHERE hosts_to_upshost.host_id=? "
          . "AND hosts.id=hosts_to_upshost.ups_id" );

    # FIXME: we return error here but is it a useful way or returning? Can it
    # be improved?
    return 'ERROR' if !$sth->execute($host_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %result = %{$reference};
        push @return_array, \%result;
    }
    return @return_array;
}

sub host_byupsid {
    my ( $dbh, $host_id ) = @_;

    return if !$dbh;
    return if !$host_id;

    my $sth =
      $dbh->prepare('SELECT host_id FROM hosts_to_upshost WHERE ups_id=?');

    # FIXME: we return error here but is it a useful way or returning? Can it
    # be improved?
    return 'ERROR' if !$sth->execute($host_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %result = %{$reference};
        push @return_array, $result{'host_id'};
    }
    return @return_array;
}

sub get_links_info {
    my $dbh           = shift;
    my $membership_id = shift;
    my $sth;

    return if !$dbh;

    if ( defined $membership_id && $membership_id !~ m/\D/x ) {
        $sth = $dbh->prepare( '
            SELECT 
              hosts_to_upshost.id AS link_id,
              hosts_to_upshost.host_id AS host_id,
              hosts1.name AS host_name,
              hosts2.name AS ups_name,
              hosts_to_upshost.ups_id AS ups_id,
              interfaces2.id AS ups_interface_id,
              interfaces2.lastresolvedfqdn AS ups_lastresolvedfqdn,
              interfaces2.address AS ups_address
            FROM 
              hosts_to_upshost,
              hosts AS hosts1,
              hosts AS hosts2,
              interfaces AS interfaces2
            WHERE 
              hosts_to_upshost.id=?
              AND interfaces2.host_id = hosts_to_upshost.ups_id
              AND hosts_to_upshost.host_id=hosts1.id
              AND hosts_to_upshost.ups_id=hosts2.id
            ' );

        return if !$sth->execute($membership_id);
    }
    else {
        $sth = $dbh->prepare( '
            SELECT 
              hosts_to_upshost.id AS link_id,
              hosts_to_upshost.host_id AS host_id, 
              hosts1.name AS host_name,
              hosts2.name AS ups_name,
              hosts_to_upshost.ups_id AS ups_id,
              interfaces2.id AS ups_interface_id,
              interfaces2.lastresolvedfqdn AS ups_lastresolvedfqdn,
              interfaces2.address AS ups_address
            FROM 
              hosts_to_upshost,
              hosts AS hosts1,
              hosts AS hosts2,
              interfaces AS interfaces2
            WHERE
              interfaces2.host_id = hosts_to_upshost.ups_id
              AND hosts_to_upshost.host_id=hosts1.id
              AND hosts_to_upshost.ups_id=hosts2.id
            ' );
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

sub get_ups_info {
    my $dbh = shift;
    return if !$dbh;

    # return all hosts in the frodo_ups and ups groups
    # this means we can make a dropdown of hosts that are just ups's
    #
    my $sth = $dbh->prepare( "
        SELECT 
          hosts.id AS ups_id,
          hosts.name AS ups_name,
          hosts.description AS ups_description
        FROM hosts
            LEFT JOIN interfaces on hosts.id = interfaces.host_id
            LEFT JOIN interfaces_to_introles ON interfaces_to_introles.interface_id = interfaces.id
            LEFT JOIN introles ON interfaces_to_introles.introle_id = introles.id
        WHERE introles.name in ('device-ups-mge', 'device-sec-ups-mge')
        ORDER BY ups_name ASC
    " );

    # FIXME - the category names should be in a config file not hardcoded vars
    return if !$sth->execute;

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub count_ups {
    my ( $dbh, $request ) = @_;
    my %message;

    if ( !defined $dbh )     { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $request ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth;
    my @raw_data = Inventory::Ups::get_ups_info($dbh);

    my %return_hash;
    if ( $request eq 'ups' ) {

        # cycle through the raw data
        # by group total up states
        foreach (@raw_data) {
            my %dbdata    = %{$_};
            my $ups_name  = $dbdata{'ups_name'};
            my $ups_state = lc $dbdata{'ups_state'};
            my $ups_id    = $dbdata{'ups_id'};

            $return_hash{$ups_name}{$ups_state}++;
            $return_hash{$ups_name}{'ups_id'} = $ups_id;
        }
    }
    elsif ( $request eq 'host' ) {

        # cycle through the raw data
        # by group total up states
        foreach (@raw_data) {
            my %dbdata    = %{$_};
            my $host_name = $dbdata{'host_name'};
            my $host_id   = $dbdata{'host_id'};
            my $state     = lc $dbdata{'state'};

            # this isn't exactly pretty but it'll work
            $return_hash{$host_name}{$state}++;
            $return_hash{$host_name}{'host_id'} = $host_id;
        }
    }
    return \%return_hash;
}

1;
__END__


=pod

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected by the overall
Inventory module is required. Other configuration is at the application level
via a configuration file loaded via Config::Tiny in the calling script, but
this module itself is only passed the resulting database handle.

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Inventory;
Inventory::Hosts 1.01;

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
