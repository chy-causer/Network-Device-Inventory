package Inventory::Suppliers;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Suppliers

=head1 VERSION

This document refers to version 1.02

=head1 SYNOPSIS

  use Inventory::Suppliers;

=head1 DESCRIPTION

Manipulate the inventory data relating to suppliers

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_suppliers
  get_suppliers_info
  edit_suppliers
  delete_suppliers
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

Readonly my $MAX_NAME_LENGTH => '128';
Readonly my $ENTRY           => 'supplier';
Readonly my $MSG_DBH_ERR     => 'Internal Error: Lost the database connection';
Readonly my $MSG_INPUT_ERR   => 'Input Error: Please check your input';
Readonly my $MSG_CREATE_OK   => "The $ENTRY creation was successful";
Readonly my $MSG_CREATE_ERR  => "The $ENTRY creation was unsuccessful";
Readonly my $MSG_EDIT_OK     => "The $ENTRY edit was successful";
Readonly my $MSG_EDIT_ERR    => "The $ENTRY edit was unsuccessful";
Readonly my $MSG_DELETE_OK   => "The $ENTRY entry was deleted";
Readonly my $MSG_DELETE_ERR  => "The $ENTRY entry could not be deleted";
Readonly my $MSG_FATAL_ERR   => 'The error was fatal, processing stopped';
Readonly my $MSG_PROG_ERR    => "$ENTRY processing tripped a software defect";

=pod

=head1 SUBROUTINES/METHODS

=head2 create_suppliers

Main creation sub.
   create_suppliers($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic supplier name sanity.

=cut

sub create_suppliers {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $input->{'supplier_name'}
        || $input->{'supplier_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'supplier_name'} < 1
        || length $input->{'supplier_name'} > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare(
'INSERT INTO suppliers(name,website,techphone,salesphone,address) VALUES(?,?,?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'supplier_name'},      $input->{'supplier_website'},
            $input->{'supplier_techphone'}, $input->{'supplier_salesphone'},
            $input->{'supplier_address'}
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_suppliers

Main edit sub.
  edit_suppliers ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for a missing database handle, supplier_id and basic supplier name sanity.

=cut

sub edit_suppliers {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $input->{'supplier_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    if (   !exists $input->{'supplier_name'}
        || $input->{'supplier_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'supplier_name'} ) < 1
        || length( $input->{'supplier_name'} ) > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare(
'UPDATE suppliers SET name=?,website=?,techphone=?,salesphone=?,address=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $input->{'supplier_name'},
            $input->{'supplier_website'},
            $input->{'supplier_techphone'},
            $input->{'supplier_salesphone'},
            $input->{'supplier_address'},

            $input->{'supplier_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }
    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 delete_suppliers

Delete a single supplier.

 delete_supplier( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_suppliers {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM suppliers WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'ERROR' => $MSG_DELETE_OK };
}

=pod

=head2 get_supplier_info

Main individual record retrieval sub. 
 get_supplier_info ( $dbh, $supplier_id )

$supplier_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

=cut

sub get_suppliers_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           suppliers.id,
           suppliers.name,
           suppliers.website,
           suppliers.techphone,
           suppliers.salesphone,
           suppliers.address
        FROM suppliers 
        WHERE
           suppliers.id = ?
        ORDER BY 
           suppliers.name
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           suppliers.id,
           suppliers.name,
           suppliers.website,
           suppliers.techphone,
           suppliers.salesphone,
           suppliers.address
        FROM suppliers 
        ORDER BY 
           suppliers.name
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
