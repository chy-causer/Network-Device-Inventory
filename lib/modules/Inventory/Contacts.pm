package Inventory::Contacts;
use strict;
use warnings;

=pod

=head1 NAME

  Inventory::Contacts

=head1 VERSION

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

=pod

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Readonly;

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

Readonly my $MAX_NAME_LENGTH => '128';
Readonly my $ENTRY           => 'contact';

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

=head2 create_contacts

Main creation sub.
create_contacts($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

The sub checks for missing database handles and bad name inputs.

=cut

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

=pod

=head2 edit_contacts

Main edit sub.
  edit_contacts ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

The sub checks for missing database handles and bad name inputs.

=cut

sub edit_contacts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $input->{'contact_name'}
        || $input->{'contact_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'contact_name'} ) < 1
        || length( $input->{'contact_name'} ) > $MAX_NAME_LENGTH )
    {

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

=pod

=head2 delete_contacts

Delete a single contacts

 delete_contacts( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

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

=pod

=head2 get_contacts_bysupplier

Delete a single contacts

 get_contacts_bysupplier( $dbh, $supplier_id );

Returns array of hashed contact details

Checks for missing database handle and id.

=cut

sub get_contacts_bysupplier {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;
    return if !defined $id;

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

=pod

=head2 get_contacts_info

Main individual record retrieval sub. 
 get_contacts_info ( $dbh, $contacts_id )

Returns the details in a hash.

=cut

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

=head1 DIAGNOSTICS

Via error messages where present.

=head1 INCOMPATIBILITIES

None known

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
