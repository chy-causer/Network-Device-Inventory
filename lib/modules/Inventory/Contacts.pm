package Inventory::Contacts;
use strict;
use warnings;

=pod

=head1 NAME

  Inventory::Contacts

=head2 VERSION

This document describes Inventory::Contacts version 1.01

=head1 SYNOPSIS

  use Inventory::Contacts;

=head1 DESCRIPTION

Functions for dealing with the Contacts related data and analysis of it.

=cut

our $VERSION = '1.01';

use base qw( Exporter);
our @EXPORT_OK = qw(
  create_contacts
  get_contacts_info
  get_contacts_bysupplier
  edit_contacts
  delete_contacts
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;
my $ENTRY           = 'contact';
my $MSG_DBH_ERR     = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR   = 'Input Error: Please check your input';
my $MSG_CREATE_OK   = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR  = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK     = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR    = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK   = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR  = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR   = 'The error was fatal, processing stopped';

sub create_contacts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $input->{'contact_name'}
        || $input->{'contact_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'contact_name'} < 1
        || length $input->{'contact_name'} > $MAX_NAME_LENGTH )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare(
'INSERT INTO contacts(name,supplier_id,role,address,telephone,email,notes) VALUES(?,?,?,?,?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'contact_name'},
            $input->{'supplier_id'},
            $input->{'contact_role'},
            $input->{'contact_address'},
            $input->{'contact_telephone'},
            $input->{'contact_email'},
            $input->{'contact_notes'}

        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

sub edit_contacts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (
           !exists $input->{'contact_name'}
        || $input->{'contact_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'contact_name'} ) < 1
        || length( $input->{'contact_name'} ) > $MAX_NAME_LENGTH{

            return { 'ERROR' => $MSG_INPUT_ERR };
        }

        my $sth = $dbh->prepare(
'UPDATE contacts SET name=?,supplier_id=?,role=?,address=?,telephone=?,email=?,notes=? WHERE id=?'
        );
        if (
            !$sth->execute(
                $input->{'contact_name'},
                $input->{'supplier_id'},
                $input->{'contact_role'},
                $input->{'contact_address'},
                $input->{'contact_telephone'},
                $input->{'contact_email'},
                $input->{'contact_notes'},

                $input->{'contact_id'}
            )
        )
        {
            return { 'ERROR' => $MSG_EDIT_ERR };
        }

        return { 'SUCCESS' => $MSG_EDIT_OK };
    }

    sub delete_contacts {
        my ( $dbh, $id ) = @_;

        if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
        if ( !defined $id )  { return { 'ERROR' => $MSG_INPUT_ERR }; }

        my $sth = $dbh->prepare('DELETE FROM contacts WHERE id=?');
        if ( !$sth->execute($id) ) {
            return { 'ERROR' => $MSG_DELETE_ERR };
        }

        return { 'SUCCESS' => $MSG_DELETE_OK };
    }

    sub get_contacts_bysupplier {
        my ( $dbh, $id ) = @_;
        my $sth;

        return if !defined $dbh;

        if ( defined $id ) {
            $sth = $dbh->prepare(
                'SELECT 
           contacts.id,
           contacts.name,
           contacts.supplier_id,
           contacts.role,
           contacts.email,
           contacts.address,
           contacts.telephone,
           contacts.notes,
           suppliers.name AS supplier_name
        FROM contacts,suppliers
        WHERE
           contacts.supplier_id=suppliers.id AND
           contacts.supplier_id = ?
        ORDER BY
           contacts.name
        '
            );
            return if !$sth->execute($id);
        }
        my @return_array;
        while ( my $reference = $sth->fetchrow_hashref ) {
            push @return_array, $reference;
        }

        return @return_array;
    }

    sub get_contacts_info {
        my ( $dbh, $id ) = @_;
        my $sth;

        return if !defined $dbh;

        if ( defined $id ) {
            $sth = $dbh->prepare(
                'SELECT 
           contacts.id,
           contacts.name,
           contacts.supplier_id,
           contacts.role,
           contacts.email,
           contacts.address,
           contacts.telephone,
           contacts.notes,
           suppliers.name AS supplier_name
        FROM contacts,suppliers
        WHERE
           contacts.supplier_id=suppliers.id AND
           contacts.id = ?
        ORDER BY
           contacts.name
        '
            );
            return if !$sth->execute($id);
        }
        else {
            $sth = $dbh->prepare(
                'SELECT 
           contacts.id,
           contacts.name,
           contacts.supplier_id,
           contacts.role,
           contacts.email,
           contacts.address,
           contacts.telephone,
           contacts.notes,
           suppliers.name AS supplier_name
        FROM contacts,suppliers
        WHERE
           contacts.supplier_id=suppliers.id
        ORDER BY
           contacts.name
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

    1;

__END__

=pod

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
