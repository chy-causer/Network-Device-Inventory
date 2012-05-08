package Inventory::Interfaces;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Interfaces

=head1 VERSION

This document describes Inventory::Interfaces version 1.03

=head1 SYNOPSIS

  use Inventory::Interfaces;

=head1 DESCRIPTION

Functions for dealing with the Interfaces table related data

=cut

our $VERSION = '1.03';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_interfaces
  edit_interfaces
  get_interfaces_info
  delete_interfaces
);

=pod

=head1 DEPENDENCIES

DBI
DBD::Pg
NetAddr::IP
Net::DNS
Readonly

=cut

use DBI;
use DBD::Pg;
use NetAddr::IP;
use Net::DNS;
use Readonly;

=pod

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's defined in the conf
directory of the following link is required.

https://github.com/guyed/Network-Device-Inventory

Other configuration is at the application level via a configuration file, but
the module is only passed the database handle.

Some text strings and string length maximum values are currently hardcoded in
the module.

=cut

Readonly my $ENTRY          = 'interface';
Readonly my $MSG_DBH_ERR    = 'Internal Error: Lost the database connection';
Readonly my $MSG_INPUT_ERR  = 'Input Error: Please check your input';
Readonly my $MSG_CREATE_OK  = "The $ENTRY creation was successful";
Readonly my $MSG_CREATE_ERR = "The $ENTRY creation was unsuccessful";
Readonly my $MSG_EDIT_OK    = "The $ENTRY edit was successful";
Readonly my $MSG_EDIT_ERR   = "The $ENTRY edit was unsuccessful";
Readonly my $MSG_DELETE_OK  = "The $ENTRY entry was deleted";
Readonly my $MSG_DELETE_ERR = "The $ENTRY entry could not be deleted";
Readonly my $MSG_FATAL_ERR  = 'The error was fatal, processing stopped';
Readonly my $MSG_PROG_ERR => "$ENTRY processing tripped a software defect";

Readonly my $MSG_PRI_EXISTS_ERR =
  'Host already has a Primary Interface, aborting';
Readonly my $MSG_IPADDRESS_ERR =
  'Must be an IPv4/6 address or resolvable DNS name';

=pod

=head1 SUBROUTINES/METHODS

=head2 create_interfaces

Main creation sub.
   create_interfaces($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle, ids, and basic address sanity.

=cut

sub create_interfaces {
    my ( $dbh, $post_ref ) = @_;
    my %posts = %{$post_ref};

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts{'interface_address'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }
    if ( !exists $posts{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $isprimary;
    if ( exists $posts{'isprimary'} && $posts{'isprimary'} eq 'true' ) {

        # check whether there is already a primary interface
        my $row = $dbh->selectrow_hashref(
'SELECT count(host_id) AS hosts FROM interfaces WHERE isprimary = true AND host_id = ?',
            {}, $posts{'host_id'},
        );
        if ( $dbh->errstr or $row->{hosts} > 0 ) {
            return { 'ERROR' => $MSG_PRI_EXISTS_ERR };
        }

        $isprimary = 'true';
    }
    else {
        $isprimary = 'false';
    }

    # chop off any address/32 or whatever as inet_aton can't cope and cries
    $posts{'interface_address'} =~ s/\/.*$//x;

    # automatically regenerate the dns on edit
    if ( !NetAddr::IP->new( $posts{'interface_address'} ) ) {
        return { 'ERROR' => $MSG_IPADDRESS_ERR };
    }

    my $address_obj = NetAddr::IP->new( $posts{'interface_address'} );
    my $res         = Net::DNS::Resolver->new;
    my $query       = $res->query( $address_obj->addr() );

    my @name;
    if ($query) {
        foreach my $rr ( $query->answer ) {
            next if $rr->type ne 'PTR';
            push @name, $rr->ptrdname;
        }
    }

    my $hostname = $name[0] || 'UNRESOLVED';

    my $sth = $dbh->prepare(
'INSERT INTO interfaces(address,host_id,lastresolvedfqdn,lastresolveddate,isprimary) VALUES(?,?,?,NOW(),?)'
    );

    if (
        !$sth->execute(
            $posts{'interface_address'}, $posts{'host_id'},
            $hostname,                   $isprimary
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'ERROR' => $MSG_CREATE_OK };
}

=pod

=head2 edit_interfaces

Main edit sub.
  edit_interfaces ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for a missing database handle, ids, and basic address sanity.

=cut

sub edit_interfaces {
    my ( $dbh, $temp_ref ) = @_;
    my %posts = %{$temp_ref};

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts{'interface_address'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }
    if ( !exists $posts{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }
    if ( !exists $posts{'interface_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    if ( !NetAddr::IP->new( $posts{'interface_address'} ) ) {
        return { 'ERROR' => $MSG_IPADDRESS_ERR };
    }

    my $isprimary;
    if ( exists $posts{'isprimary'} && $posts{'isprimary'} eq 'true' ) {

        # check whether there is already another primary interface
        my $row = $dbh->selectrow_hashref(
'SELECT count(id) AS intcount FROM interfaces WHERE isprimary = true AND host_id = ? AND id != ?',
            {}, $posts{'host_id'}, $posts{'interface_id'},
        );
        if ( $dbh->errstr or $row->{intcount} > 0 ) {
            return { 'ERROR' => $MSG_PRI_EXISTS_ERR };
        }

        $isprimary = 'true';
    }
    else {
        $isprimary = 'false';
    }

    # chop off any address/32 or whatever as inet_aton can't cope and cries
    $posts{'interface_address'} =~ s/\/.*$//x;

    # automatically regenerate the dns on edit
    if ( !NetAddr::IP->new( $posts{'interface_address'} ) ) {
        return { 'ERROR' => $MSG_IPADDRESS_ERR };
    }

    my $address_obj = NetAddr::IP->new( $posts{'interface_address'} );
    my $res         = Net::DNS::Resolver->new;
    my $query       = $res->query( $address_obj->addr() );

    my @name;
    if ($query) {
        foreach my $rr ( $query->answer ) {
            next if $rr->type ne 'PTR';
            push @name, $rr->ptrdname;
        }
    }

    my $hostname = $name[0] || 'UNRESOLVED';

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
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_interfaces_info

Main individual record retrieval sub. 
  get_interfaces_info ( $dbh )
  get_interfaces_info ( $dbh, $interface_id )
  get_interfaces_info ( $dbh, , $host_id, $interface_address )

$interface_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

=cut

sub get_interfaces_info {
    my $dbh               = shift;
    my $interface_id      = shift;
    my $host_id           = shift;
    my $interface_address = shift;

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

=pod

=head2 delete_interfaces

Delete a single interface.

 delete_interfaces( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_interfaces {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM interfaces WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

1;
__END__

=pod

=head1 DIAGNOSTICS

Via error messages where present.

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
