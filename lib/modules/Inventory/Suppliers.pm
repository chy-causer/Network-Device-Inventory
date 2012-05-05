package Inventory::Suppliers;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Suppliers

=head1 VERSION

This document refers to version 1.01

=head1 DESCRIPTION

Manipulate the invenotry data relating to suppliers

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_suppliers
  get_suppliers_info
  edit_suppliers
  delete_suppliers
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;
my $ENTRY           = 'supplier';
my $MSG_DBH_ERR     = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR   = 'Input Error: Please check your input';
my $MSG_CREATE_OK   = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR  = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK     = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR    = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK   = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR  = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR   = 'The error was fatal, processing stopped';

sub create_suppliers {
    my ( $dbh, $input ) = @_;
    my %message;
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

sub edit_suppliers {

    # similar to creating a supplier except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;
    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (

        !exists $input->{'supplier_name'}
        || $input->{'supplier_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'supplier_name'} ) < 1
        || length( $input->{'supplier_name'} ) > $MAX_NAME_LENGTH

        || !exists $input->{'supplier_id'}
        || $input->{'supplier_id'} !~ m/^[\d]+$/x

      )
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
