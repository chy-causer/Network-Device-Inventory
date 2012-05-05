package Inventory::Invoices;
use strict;
use warnings;

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_invoices
  get_invoices_info
  edit_invoices
  delete_invoices
);

use DBI;
use DBD::Pg;

my $ENTRY          = 'invoice';
my $MSG_DBH_ERR    = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR  = 'Input Error: Please check your input';
my $MSG_CREATE_OK  = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK    = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR   = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK  = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR  = 'The error was fatal, processing stopped';

sub create_invoices {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my $sth = $dbh->prepare(
        'INSERT INTO invoices(
                          supplier_id,date,description,
                          purchaser_id,signitory_id,totalcost,
                          ponumber,reqnumber,costcentre,
                          natacct) 
                          VALUES(?,?,?,?,?,?,?,?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'supplier_id'},         $input->{'invoice_date'},
            $input->{'invoice_description'}, $input->{'purchaser_id'},
            $input->{'signitory_id'},        $input->{'invoice_totalcost'},
            $input->{'invoice_ponumber'},    $input->{'invoice_reqnumber'},
            $input->{'invoice_costcentre'},  $input->{'invoice_natacct'}
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return {'SUCCESS'} = $MSG_CREATE_OK;
}
}

sub edit_invoices {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if ( !exists $input->{'invoice_description'} ) {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare(
'UPDATE invoices SET supplier_id=?,date=?,description=?,purchaser_id=?,signitory_id=?,totalcost=?,ponumber=?,reqnumber=?,costcentre=?,natacct=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $input->{'supplier_id'},
            $input->{'invoice_date'},
            $input->{'invoice_description'},
            $input->{'purchaser_id'},
            $input->{'signitory_id'},
            $input->{'invoice_totalcost'},
            $input->{'invoice_ponumber'},
            $input->{'invoice_reqnumber'},
            $input->{'invoice_costcentre'},
            $input->{'invoice_natacct'},

            $input->{'invoice_id'},
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

sub delete_invoices {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM invoices WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR } :;
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

sub get_invoices_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           invoices.id,
           invoices.description,
           invoices.supplier_id,
           invoices.signitory_id,
           scontacts.name AS signitory_name,
           invoices.purchaser_id,
           pcontacts.name AS purchaser_name,
           invoices.date,
           invoices.description,
           invoices.totalcost,
           invoices.ponumber,
           invoices.reqnumber,
           invoices.natacct,
           invoices.costcentre,
           suppliers.name AS supplier_name
        FROM invoices,
             suppliers,
             contacts AS scontacts,
             contacts AS pcontacts
        WHERE
           invoices.supplier_id = suppliers.id
        AND
           invoices.signitory_id = scontacts.id
        AND
           invoices.purchaser_id = pcontacts.id
        AND
           invoices.id = ?
        ORDER BY 
           invoices.description
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           invoices.id,
           invoices.description,
           invoices.supplier_id,
           invoices.signitory_id,
           scontacts.name AS signitory_name,
           invoices.purchaser_id,
           pcontacts.name AS purchaser_name,
           invoices.date,
           invoices.description,
           invoices.totalcost,
           invoices.ponumber,
           invoices.reqnumber,
           invoices.natacct,
           invoices.costcentre,
           suppliers.name AS supplier_name
        FROM invoices,
             suppliers,
             contacts AS scontacts,
             contacts AS pcontacts
        WHERE
           invoices.supplier_id = suppliers.id
        AND
           invoices.signitory_id = scontacts.id
        AND
           invoices.purchaser_id = pcontacts.id
        ORDER BY 
           invoices.description
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

=head1 NAME

Inventory::Invoices - Manipulate Invoices

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
