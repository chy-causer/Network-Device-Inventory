#!/usr/bin/perl -T
#
# Name: Interfaces.pm
# Creator: Guy Edwards
# Created: 2008-08-05
# Description: unknown
#
# $Id: Interfaces.pm 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: 5KN1VboihA3ux9Ps7rDNLV6Lr2x5oQzS5uzjB0_nHcWvP $
#
package Inventory::Interfaces;
use strict;
use warnings;

our $VERSION = qw('1.0.2');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_interfaces
  edit_interfaces
  get_interfaces_info
  delete_interface
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;
use Socket;
use NetAddr::IP;

sub create_interfaces {
    my ( $dbh, $post_ref ) = @_;
    my %posts = %{$post_ref};
    my %message;

    # just a basic test
    if (  !exists $posts{'interface_address'}
        || length $posts{'interface_address'} < 1 )
    {

        $message{'ERROR'} =
'Input Error: It looks like you forgot to fill in an address for the interface';
        return \%message;
    }

    if (   !exists $posts{'host_id'}
        || $posts{'host_id'} =~ m/\D/x
        || length( $posts{'host_id'} ) < 1 )
    {
        $message{'ERROR'} =
'Input Error: Programming error? It looks like no host was supplied for the interface';
        return \%message;
    }

    my $isprimary;
    if ( exists $posts{'isprimary'} && $posts{'isprimary'} eq 'true' ) {

        # check whether there is already a primary interface
        my $row = $dbh->selectrow_hashref(
'SELECT count(host_id) AS hosts FROM interfaces WHERE isprimary = true AND host_id = ?',
            {}, $posts{'host_id'},
        );
        if ( $dbh->errstr or $row->{hosts} > 0 ) {
            $message{'ERROR'} =
'Input Error: Primary Interface already exists. Cannot create another Primary Interface';
            return \%message;
        }

        $isprimary = 'true';
    }
    else {
        $isprimary = 'false';
    }

    # chop off any address/32 or whatever as inet_aton can't cope and cries
    $posts{'interface_address'} =~ s/\/.*$//x;

    # automatically regenerate the dns on edit
    my $address;
    my $hostname;

    # ipv6 enable the subroutine
    if ( !NetAddr::IP->new( $posts{'interface_address'} ) ) {

        # ok, it's not an address
        $message{'ERROR'} =
'Input Error: The input does not seem to be an IPv4/6 address or a resolvable hostname';
        return \%message;
    }

    my $object_address = NetAddr::IP->new( $posts{'interface_address'} );
    my $bareip         = $object_address->addr();

    my $subaddress = inet_aton($bareip);
    if ($subaddress) {
        my $realaddress = inet_ntoa($subaddress);
        $hostname =
          ( ( ( gethostbyaddr inet_aton($realaddress), AF_INET )[0] )
              || 'UNRESOLVED' );
    }
    else {
        $hostname = 'UNRESOLVED';
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand

    my $sth = $dbh->prepare(
'INSERT INTO interfaces(address,host_id,lastresolvedfqdn,lastresolveddate,isprimary) VALUES(?,?,?,NOW(),?)'
    );

    if ( !$sth->execute( $bareip, $posts{'host_id'}, $hostname, $isprimary ) ) {
        $message{'ERROR'} =
          'Internal Error: The interface creation was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'The interface creation was successful';
    return \%message;
}

sub edit_interfaces {
    my ( $dbh, $temp_ref ) = @_;
    my %posts = %{$temp_ref};
    my %message;

    # dump bad inputs
    if (
          !exists $posts{'interface_id'}
        || length( $posts{'interface_id'} ) < 1
        || $posts{'interface_id'} =~ m/\D/x

        || !exists $posts{'host_id'}
        || length( $posts{'host_id'} ) < 1
        || $posts{'host_id'} =~ m/\D/x

        || !exists $posts{'interface_address'}
        || length( $posts{'interface_address'} ) < 1

        # ipv6 enable the subroutine
        || !NetAddr::IP->new( $posts{'interface_address'} )
      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: One of the supplied inputs was invalid.';
        return \%message;
    }

    my $isprimary;
    if ( exists $posts{'isprimary'} && $posts{'isprimary'} eq 'true' ) {

        # check whether there is already another primary interface
        my $row = $dbh->selectrow_hashref(
'SELECT count(id) AS intcount FROM interfaces WHERE isprimary = true AND host_id = ? AND id != ?',
            {}, $posts{'host_id'}, $posts{'interface_id'},
        );
        if ( $dbh->errstr or $row->{intcount} > 0 ) {
            $message{'ERROR'} =
'Input Error: Primary Interface already exists. Cannot create another Primary Interface';
            return \%message;
        }

        $isprimary = 'true';
    }
    else {
        $isprimary = 'false';
    }

    # chop off any address/32 or whatever as inet_aton can't cope and cries
    $posts{'interface_address'} =~ s/\/.*$//x;

    # automatically regenerate the dns on edit
    my $address;
    my $hostname;

    # ipv6 enable the subroutine
    if ( !NetAddr::IP->new( $posts{'interface_address'} ) ) {

        # ok, it's not an address
        $message{'ERROR'} =
'Input Error: The input does not seem to be an IPv4/6 address or a resolvable hostname';
        return \%message;
    }

    my $object_address = NetAddr::IP->new( $posts{'interface_address'} );
    my $bareip         = $object_address->addr();

    my $subaddress = inet_aton($bareip);
    if ($subaddress) {
        my $realaddress = inet_ntoa($subaddress);
        $hostname =
          ( ( ( gethostbyaddr inet_aton($realaddress), AF_INET )[0] )
              || 'UNRESOLVED' );
    }
    else {
        $hostname = 'UNRESOLVED';
    }

    my $sth = $dbh->prepare(
'UPDATE interfaces SET host_id=?,address=?,lastresolvedfqdn=?,lastresolveddate=NOW(),isprimary=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $posts{'host_id'}, $posts{'interface_address'},
            $hostname,         $isprimary,
            $posts{'interface_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The interface edit was unsuccessful.';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your interface changes were commited successfully';
    return \%message;
}

sub get_interfaces_info {

    # three ways to call this
    my $dbh = shift;

    # 1) with no information - list everything
    # 2) with  an interface id
    my $interface_id = shift;

    # 3) via a host/address combination
    my $host_id           = shift;
    my $interface_address = shift;

    # [/end sparce documentation]
    my $sth;

    return if !defined $dbh;

    if (   defined $interface_id
        && $interface_id !~ m/\D/x
        && length($interface_id) > 0 )
    {
        $sth = $dbh->prepare(
            'SELECT 
           interfaces.id,
           interfaces.host_id,
           interfaces.address,
           interfaces.lastresolvedfqdn,
           interfaces.lastresolveddate,
           interfaces.isprimary,
           hosts.name AS host_name,
           status.state,
           hosts.status_id
        FROM interfaces,hosts,status 
        WHERE 
           hosts.id=interfaces.host_id
           AND hosts.status_id = status.id
           AND interfaces.id=? 
        ORDER BY 
           hosts.name, interfaces.isprimary DESC'
        );
        return if !$sth->execute($interface_id);
    }
    elsif ( defined $host_id && defined $interface_address ) {

        # we need this to add services to the correct interface
        # on the quickadd page
        $sth = $dbh->prepare(
            'SELECT 
           interfaces.id,
           interfaces.host_id,
           interfaces.address,
           interfaces.lastresolvedfqdn,
           interfaces.lastresolveddate,
           interfaces.isprimary,
           hosts.name AS host_name,
           status.state,
           hosts.status_id
        FROM interfaces,hosts,status 
        WHERE 
           hosts.id=interfaces.host_id 
           AND hosts.status_id = status.id
           AND interfaces.host_id=?
           AND interfaces.address=?
        ORDER BY 
           hosts.name, interfaces.isprimary DESC'
        );
        return if !$sth->execute( $host_id, $interface_address );
    }
    elsif ( defined $host_id ) {

        $sth = $dbh->prepare(
            'SELECT 
           interfaces.id,
           interfaces.host_id,
           interfaces.address,
           interfaces.lastresolvedfqdn,
           interfaces.lastresolveddate,
           interfaces.isprimary,
           hosts.name AS host_name,
           status.state,
           hosts.status_id
        FROM interfaces,hosts,status 
        WHERE 
           hosts.id=interfaces.host_id 
           AND hosts.status_id = status.id
           AND interfaces.host_id=?
        ORDER BY 
           hosts.name, interfaces.isprimary DESC'
        );
        return if !$sth->execute($host_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
            interfaces.id,
            interfaces.host_id,
            interfaces.address,
            interfaces.lastresolvedfqdn,
            interfaces.lastresolveddate,
           interfaces.isprimary,
           hosts.name AS host_name,
           status.state,
           hosts.status_id
        FROM interfaces,hosts,status 
        WHERE 
           hosts.id=interfaces.host_id 
           AND hosts.status_id = status.id
        ORDER BY 
           hosts.name, interfaces.isprimary DESC'
        );
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

sub delete_interface {

    my $dbh          = shift;
    my $interface_id = shift;

    return { 'ERROR' => 'Programming error' } if !defined $dbh;
    return { 'ERROR' => 'Programming error, no interface_id' }
      if !defined $interface_id;
    return { 'ERROR' => "Programming error, $interface_id contains non digits" }
      if $interface_id =~ m/\D/x;
    return { 'ERROR' => 'Programming error, empty interface_id' }
      if length($interface_id) < 1;

    my $sth = $dbh->prepare('DELETE FROM interfaces WHERE id=?');
    return {
        'ERROR' => 'Programming error, database refused to delete the record' }
      if !$sth->execute($interface_id);

    # congratulations, you made it
    return { 'SUCCESS' => 'Interface deleted' };
}

1;
__END__

=head1 NAME

Inventory::Interfaces - Networks team inventory module

=head1 VERSION

This document describes Inventory::Interfaces version 1.0.2

=head1 SYNOPSIS

use Inventory::Interfaces;

=head1 DESCRIPTION

Module to handle the validation, addition, editing and retrieval of interface
information in the inventory database

=head1 RETURNS

All returns from lists operations are arrays of hashes

All creates and edits return a hash, the key gives success or failure, the
value gives the human message of what went wrong.

=head1 OPTIONS

see the subroutines/methods section

=head1 USAGE

edit an interface
%message = %{ Inventory::Interfaces::edit_interfaces( $dbh, \%POSTS ) };

create an interface
%message = %{ Inventory::Interfaces::create_interfaces( $dbh, \%POSTS ) };

list all the interfaces (array of hashes)
my @interfaces = Inventory::Interfaces::get_interfaces_info($dbh);

=head1 REQUIRED ARGUEMENTS

All subroutines require the database handle be passed to them

=head1 SUBROUTINES/METHODS

=head2 create_interfaces( %form_data )
  
  create new entries in the interfaces table

=head2 edit_interfaces( %form_data )
  
  edit existing entries in the interfaces table

=head2 get_interfaces_info

  list existing entries in the interfaces table as an array of hashes
 
  Call with no extra arguements to list all entries
  get_interfaces_info( database handle)

  Call with an interface id to get the details of one interface alone
  get_interfaces_info( database handle, interface_id )

  Call with a host id / ip address combination to retrieve the specific interface
  get_interfaces_info( database handle, undef, host_id, ipv4/ipv6 address )


=head1 DIAGNOSTICS

  Errors should be reported back to the user via the web interface

=head1 CONFIGURATION

A postgres database with the database layout that's expected is required.
Other configuration is at the application level via a configuration file, but
the module is only passed the database handle.

=head1 DEPENDENCIES

DBI, DBD::Pg, Regexp::Common, NetAddr::IP, Socket

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
