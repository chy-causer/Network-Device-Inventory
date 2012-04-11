package Inventory::Contracts;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_contracts
  get_contracts_info
  edit_contracts
  delete_contracts
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;

sub create_contracts {

    # respond to a request to create a contract
    # 1. validate input
    # 2. make the database entry
    # 3. return success or fail
    #
    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'contract_name'}
        || $input->{'contract_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'contract_name'} < 1
        || length $input->{'contract_name'} > $MAX_NAME_LENGTH )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }
    if( $input->{'invoice_id'} eq '' ){
        $input->{'invoice_id'} = undef;
    }
    if( $input->{'servicelevel_id'} eq '' ){
        $input->{'servicelevel_id'} = undef;
    }

    my $sth = $dbh->prepare(
'INSERT INTO contracts(name,serial,startdate,enddate,invoice_id,servicelevel_id) VALUES(?,?,?,?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'contract_name'},
            $input->{'contract_serial'},
            $input->{'contract_startdate'},
            $input->{'contract_enddate'},
            $input->{'invoice_id'},
            $input->{'servicelevel_id'},

        )
      )
    {
        $message{'ERROR'} =
          "Internal Error: The contract creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The contract creation was successful';
    return \%message;
}

sub edit_contracts {

    # similar to creating a contract except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'contract_name'}
        || $input->{'contract_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'contract_name'} ) < 1
        || length( $input->{'contract_name'} ) > $MAX_NAME_LENGTH
        || !exists $input->{'contract_id'}
        || $input->{'contract_id'} !~ m/^[\d]+$/x )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }
    if( $input->{'invoice_id'} eq '' ){
        $input->{'invoice_id'} = undef;
    }
    if( $input->{'servicelevel_id'} eq '' ){
        $input->{'servicelevel_id'} = undef;
    }

    my $sth = $dbh->prepare(
'UPDATE contracts SET name=?,serial=?,startdate=?,enddate=?,invoice_id=?,servicelevel_id=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $input->{'contract_name'},
            $input->{'contract_serial'},
            $input->{'contract_startdate'},
            $input->{'contract_enddate'},
            $input->{'invoice_id'},
            $input->{'servicelevel_id'},

            $input->{'contract_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The contract entry edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your contract changes were commited successfully';
    return \%message;
}

sub delete_contracts {

    # delete a single contract

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM contracts WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The contract entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
}

sub get_contracts_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           contracts.id,
           contracts.name,
           contracts.startdate,
           contracts.enddate,
           contracts.serial,
           contracts.invoice_id,
           invoices.description AS invoice_description,
           servicelevels.description AS servicelevel_description,
           servicelevels.name AS servicelevel_name,
           servicelevels.id AS servicelevel_id

        FROM contracts 
            LEFT JOIN invoices on invoices.id = contracts.invoice_id
            LEFT JOIN servicelevels on servicelevels.id = contracts.servicelevel_id
        WHERE 
           invoices.id = contracts.invoice_id,
           contracts.id = ?
        
        ORDER BY 
           contracts.name
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           contracts.id,
           contracts.name,
           contracts.startdate,
           contracts.enddate,
           contracts.serial,
           contracts.invoice_id,
           invoices.description AS invoice_description,
           servicelevels.description AS servicelevel_description,
           servicelevels.name AS servicelevel_name,
           servicelevels.id AS servicelevel_id
        
        FROM contracts 
            LEFT JOIN invoices on invoices.id = contracts.invoice_id
            LEFT JOIN servicelevels on servicelevels.id = contracts.servicelevel_id

        ORDER BY 
           contracts.name
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

Inventory::Contracts - Manipulate Contracts

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
