package Inventory::Invoices;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Invoices

=head1 VERSION

This document describes Inventory::Invoices version 1.04

=head1 SYNOPSIS

  use Inventory::Invoices;

=head1 DESCRIPTION

Module for manipulating the interface to interface role information

=cut

our $VERSION = '1.04';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_invoices
  get_invoices_info
  edit_invoices
  delete_invoices
  get_hosts_byinvoice
  cost_per_month
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

Readonly my $ENTRY          => 'invoice';
Readonly my $MSG_DBH_ERR    => 'Internal Error: Lost the database connection';
Readonly my $MSG_INPUT_ERR  => 'Input Error: Please check your input';
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

=head2 create_invoices

Main creation sub.
create_invoices($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic invoice name sanity.

=cut

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

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_invoices

Main edit sub.
  edit_invoices ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Currently the only error check is for a missing database handle.

=cut

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

=pod

=head2 delete_invoices

Delete a single invoice

 delete_invoices( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_invoices {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM invoices WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 get_invoices_info

Main individual record retrieval sub. 
 get_invoices_info ( $dbh, $invoice_id )

$invoice_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

=cut

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

=pod

=head2 get_hosts_byinvoice

Retrieve all hosts associated with a given invoice.
 get_hosts_byinvoice ( $dbh, $invoice_id )

Returns the details in a array of hashes.

=cut

sub get_hosts_byinvoice {
    my ( $dbh, $id ) = @_;

    return if !defined $dbh;
    return if !defined $id;

    my $sth = $dbh->prepare( '
         SELECT 
           hosts.id,
           hosts.name,
           hosts.description,
           hosts.location_id,
           hosts.status_id,
           hosts.asset,
           hosts.serial,
           hosts.model_id,
           hosts.lastchecked,
           status.state AS status_state,
           status.description AS status_description,
           locations.name AS location_name,
           models.name AS model_name,
           manufacturers.name AS manufacturer_name,
           manufacturers.id AS manufacturer_id
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
         
         WHERE
           invoice_id=?
         ORDER BY
           hosts.name
        
        ' );
    return if !$sth->execute($id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 hash_hosts_perinvoice

Return all hosts, indexed by invoice

=cut

sub hash_hosts_perinvoice {
    my ($dbh) = @_;

    return if !defined $dbh;

    my $sth = $dbh->prepare( '
         SELECT 
           hosts.id,
           hosts.name,
           hosts.description,
           hosts.location_id,
           hosts.status_id,
           hosts.asset,
           hosts.serial,
           hosts.model_id,
           hosts.lastchecked,
           status.state AS status_state,
           status.description AS status_description,
           locations.name AS location_name,
           locations.id AS location_id,
           models.name AS model_name,
           manufacturers.name AS manufacturer_name,
           manufacturers.id AS manufacturer_id,
           hosts.invoice_id,
           invoices.date AS invoice_date,
           invoices.description AS invoice_description
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
          LEFT JOIN invoices
          ON hosts.invoice_id=invoices.id
         
         ORDER BY
           hosts.name
        
        ' );
    return if not $sth->execute();

    my %index;
    while ( my $ref = $sth->fetchrow_hashref ) {
       
        next if not exists  $ref->{'invoice_description'};
        next if not defined $ref->{'invoice_description'};
        next if length $ref->{'invoice_description'} < 1;
        
        if ( !exists $index{ $ref->{'invoice_description'} } ) {
            my @data = ($ref);
            $index{ $ref->{'invoice_description'} } = \@data;
        }
        else {
            push @{ $index{ $ref->{'invoice_description'} } }, $ref;
        }
    }


    return \%index;
}

=pod

=head2 cost_per_month

Returns the total expenditure totalled per month, for example

    2011-01-01 4123.45
    2012-02-01 6204.12

=cut

sub cost_per_month {
    my ($dbh) = @_;

    return if !defined $dbh;

    my $sth = $dbh->prepare("
               SELECT 
                     SUM(totalcost) AS cost,
                     date_trunc('month', date)::date AS month,
                     date_part('epoch', (date AT TIME ZONE 'GMT')::timestamp)*1000 AS month_javascript 
               FROM invoices
               GROUP BY month, month_javascript
               ORDER BY month_javascript
        ");
    return if not $sth->execute();

    my @data;
    while ( my $ref = $sth->fetchrow_hashref ) {
          push @data, $ref;
    }
    
    return @data;
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
