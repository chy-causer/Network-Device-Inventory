package Inventory::Sshkeys;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Sshkeys

=head1 VERSION

This document describes Inventory::Sshkeys version 1.01

=head1 SYNOPSIS

  use Inventory::Sshkeys;

=head1 DESCRIPTION

Module for manipulating the hosts sshkeys data

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_sshkeys
  delete_sshkeys
  edit_sshkeys
  get_sshkeys_info
  sshkeys_byhostid
);

=pod

=head1 DEPENDENCIES

DBI
DBD::Pg
Readonly

=cut

use DBI;
use DBD::Pg;
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

Readonly my $MAX_KEY_LENGTH => '48';

Readonly my $ENTRY          => 'SSH key';
Readonly my $MSG_DBH_ERR    => 'Internal Error: Lost the database connection';
Readonly my $MSG_INPUT_ERR  => "Please check your $ENTRY data input";
Readonly my $MSG_CREATE_OK  => "The $ENTRY creation was successful";
Readonly my $MSG_CREATE_ERR => "The $ENTRY creation was unsuccessful";
Readonly my $MSG_EDIT_OK    => "The $ENTRY edit was successful";
Readonly my $MSG_EDIT_ERR   => "The $ENTRY edit was unsuccessful";
Readonly my $MSG_DELETE_OK  => "The $ENTRY entry was deleted";
Readonly my $MSG_DELETE_ERR => "The $ENTRY entry could not be deleted";
Readonly my $MSG_FATAL_ERR  => 'The error was fatal, processing stopped';
Readonly my $MSG_PROG_ERR   => "$ENTRY processing tripped a software defect";

=pod

=head1 SUBROUTINES/METHODS

=head2 create_sshkeys

Main creation sub.
create_sshkeys($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

For the fingerprint we strip any leading and trailing whitespace as well as
trailing dot characters to make life easier for people pasting sshkeys from
terminals

Checks for a missing database handle, host_id and basic sshkey sanity.

=cut

sub create_sshkeys {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    if ( exists $posts->{'sshkey_fingerprint'} ) {
        $posts->{'sshkey_fingerprint'} =~ s/\s//g;
        $posts->{'sshkey_fingerprint'} =~ s/\.$//g;
    }

    if ( !exists $posts->{'sshkey_fingerprint'}
        || $posts->{'sshkey_fingerprint'} !~
        m/^([a-zA-Z0-9]{2}:)+([a-zA-Z0-9]{2})$/x
        || length( $posts->{'sshkey_fingerprint'} ) < 1
        || length( $posts->{'sshkey_fingerprint'} ) > $MAX_KEY_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth =
      $dbh->prepare('INSERT INTO sshkeys(fingerprint,host_id) VALUES(?,?)');

    if ( !$sth->execute( $posts->{'sshkey_fingerprint'}, $posts->{'host_id'} ) )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_sshkeys

Main edit sub.
  edit_sshkeys ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

For the fingerprint we strip any leading and trailing whitespace as well as
trailing dot characters to make life easier for people pasting sshkeys from
terminals

Checks for a missing database handle, host_id and basic sshkey sanity.

=cut

sub edit_sshkeys {
    my ( $dbh, $posts ) = @_;
    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    if ( !exists $posts->{'sshkey_fingerprint'}
        || $posts->{'sshkey_fingerprint'} !~
        m/^([a-zA-Z0-9]{2}:)+([a-zA-Z0-9]{2})$/x
        || length( $posts->{'sshkey_fingerprint'} ) < 1
        || length( $posts->{'sshkey_fingerprint'} ) > $MAX_KEY_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth =
      $dbh->prepare('UPDATE sshkeys SET host_id=?,fingerprint=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'sshkey_fingerprint'},
            $posts->{'sshkey_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 sshkeys_byhostid

Return all records relating to a specific host_id

Returns the details in a array of hashes.

=cut

sub sshkeys_byhostid {
    my ( $dbh, $host_id ) = @_;

    return if !$dbh;
    return if !$host_id;

    my $sth =
      $dbh->prepare('SELECT id,fingerprint FROM sshkeys WHERE host_id=?');

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

=pod

=head2 get_sshkeys_info

Main individual record retrieval sub. 
 get_sshkeys_info ( $dbh )
 get_sshkeys_info ( $dbh, $sshkey_id )

The $sshkey_id is optional, if not given all keys will be returned

Returns the details in a hash.

=cut

sub get_sshkeys_info {
    my ( $dbh, $sshkey_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $sshkey_id ) {
        $sth = $dbh->prepare(
            'SELECT 
            sshkeys.id,
            sshkeys.fingerprint,
            sshkeys.host_id,
            hosts.name AS host_name,
            hosts.id   AS host_id,
            hosts.status_id,
            status.state
         FROM 
            sshkeys,hosts,status
         WHERE
            sshkeys.host_id = hosts.id
            AND status.id = hosts.status_id
            AND sshkeys.id=?
         ORDER BY
            hosts.name
        '
        );
        return if !$sth->execute($sshkey_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
            sshkeys.id,
            sshkeys.fingerprint,
            sshkeys.host_id,
            hosts.name AS host_name,
            hosts.id   AS host_id,
            hosts.status_id,
            status.state
         FROM 
            sshkeys,hosts,status
         WHERE
            sshkeys.host_id = hosts.id
            AND status.id = hosts.status_id
         ORDER BY 
            hosts.name
        '
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

=head2 delete_sshkeys

Delete a single entry.
 delete_sshkeys( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_sshkeys {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM sshkeys WHERE id=?');
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
