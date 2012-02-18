package Inventory::Invoices;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_invoices
  get_invoices_info
  edit_invoices
  delete_invoices
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;

sub create_invoices {

    # respond to a request to create a invoice
    # 1. validate input
    # 2. make the database entry
    # 3. return success or fail
    #
    my ( $dbh, $input ) = @_;
    my %message;

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
        $message{'ERROR'} =
          "Internal Error: The invoice creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The invoice creation was successful';
    return \%message;
}

sub edit_invoices {

    # similar to creating a invoice except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;

    if ( !exists $input->{'invoice_description'} ) {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
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
        $message{'ERROR'} =
          'Internal Error: The invoice entry edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your invoice changes were commited successfully';
    return \%message;
}

sub delete_invoices {

    # delete a single invoice

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM invoices WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The invoice entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
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

The University of Oxford disclaims all copyright interest in the program
`Inventory' written by Guy Edwards as agreed by Dr. Stuart Lee, Director of
Oxford University Computer Services.

Oliver Gorwits, who in 2008 contributed sections of the hostgroups programming
also disclaims all copyright interest in the program.
