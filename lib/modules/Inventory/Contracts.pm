package Inventory::Contracts;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Contracts

=head1 VERSION

This document describes Inventory::Contracts version 1.01

=head1 SYNOPSIS

  use Inventory::Contracts;

=head1 DESCRIPTION

Functions for dealing with the Contracts related data and analysis of it.

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_contracts
  edit_contracts
  delete_contracts
  get_contracts_info
  hosts_bycontract_id
  hosts_bycontract_name
  hash_hosts_percontract
  count_hosts_percontract
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
Readonly my $ENTRY           => 'contract';

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

=head2 create_contracts

Main creation sub.
create_contracts($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

The sub checks for missing database handles and bad name inputs.

=cut

sub create_contracts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $input->{'contract_name'}
        || $input->{'contract_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'contract_name'} < 1
        || length $input->{'contract_name'} > $MAX_NAME_LENGTH )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }
    if ( $input->{'invoice_id'} eq '' ) {
        $input->{'invoice_id'} = undef;
    }
    if ( $input->{'servicelevel_id'} eq '' ) {
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
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_contracts

Main edit sub.
  edit_contracts ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

The sub checks for missing database handles and bad name inputs.

=cut

sub edit_contracts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $input->{'contract_name'}
        || $input->{'contract_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'contract_name'} ) < 1
        || length( $input->{'contract_name'} ) > $MAX_NAME_LENGTH )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }
    if ( $input->{'invoice_id'} eq '' ) {
        $input->{'invoice_id'} = undef;
    }
    if ( $input->{'servicelevel_id'} eq '' ) {
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
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 delete_contracts

Delete a single contracts.

 delete_contracts( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and entry id.

=cut

sub delete_contracts {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM contracts WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 get_contracts_info

Main individual record retrieval sub. 
 get_contracts_info ( $dbh, $contracts_id )

Returns the details in a hash.

=cut

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
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS enddate_daysremaining,
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
        return if !$sth->execute('days','days',$id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           contracts.id,
           contracts.name,
           contracts.startdate,
           contracts.enddate,
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS enddate_daysremaining,
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
        return if !$sth->execute('days','days');
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

=pod

=head2 hosts_bycontract_name

Return all hosts for a given contract (based on name).

  hosts_bycontract_name ( $dbh, $name )

Returns empty if either argument is missing.

Returns an array of hosts hashes if successful.

=cut

sub hosts_bycontract_name {
    my ( $dbh, $name ) = @_;

    return if !defined $dbh;
    return if !defined $name;

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
           manufacturers.id AS manufacturer_id,
           contracts.id AS contract_id,
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS contract_enddate_daysremaining,
           contracts.name AS contract_name
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
          LEFT JOIN hoststocontracts
          ON hoststocontracts.host_id=hosts.id
          LEFT JOIN contracts
          ON hoststocontracts.contract_id=contracts.id
         
         WHERE contract.name=?

         ORDER BY
           hosts.name
        ' );

    return if !$sth->execute('days', 'days', $name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 hosts_bycontract_id

Return all hosts for a given contract (based on id).

  hosts_bycontract_name ( $dbh, $name )

Returns empty if either argument is missing.

Returns an array of hosts hashes if successful.

=cut

sub hosts_bycontract_id {
    my ( $dbh, $name ) = @_;

    return if !defined $dbh;
    return if !defined $name;

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
           manufacturers.id AS manufacturer_id,
           contracts.id AS contract_id,
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS contract_enddate_daysremaining,
           contracts.name AS contract_name
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
          LEFT JOIN hoststocontracts
          ON hoststocontracts.host_id=hosts.id
          LEFT JOIN contracts
          ON hoststocontracts.contract_id=contracts.id
         
         WHERE contract.id=?

         ORDER BY
           hosts.name
        ' );

    return if !$sth->execute('days','days',$name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=head2 hash_hosts_percontract

return all hosts indexed by contract

 hash_hosts_percontract ($dbh)

returns a hash

 $contract_name => @hosts

where @hosts is an array of individual hashes, each has containing a hosts
data.

=cut

sub hash_hosts_percontract {
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
           contracts.id AS contract_id,
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS contract_enddate_daysremaining,
           contracts.name AS contract_name
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
          LEFT JOIN hoststocontracts
          ON hoststocontracts.host_id=hosts.id
          LEFT JOIN contracts
          ON hoststocontracts.contract_id=contracts.id
         
         ORDER BY
           hosts.name
        
        ' );
    return if not $sth->execute('days','days');

    my %index;
    while ( my $ref = $sth->fetchrow_hashref ) {
        next if !exists $ref->{'contract_id'};
        next if !defined $ref->{'contract_id'};
        next if length $ref->{'contract_id'} < 1;

        if ( !exists( $index{ $ref->{'contract_id'} } ) ) {
            my @data = ($ref);
            $index{ $ref->{'contract_id'} } = \@data;
        }
        else {
            push @{ $index{ $ref->{'contract_id'} } }, $ref;
        }
    }

    return \%index;
}

=pod

=head2 count_hosts_percontract

Return total number of hosts per contract.

 count_hosts_percontract($dbh)

Returns a slightly complex has that includes state.

  %return{$contract_id}
               {$state}{$number_of_hosts}
               {contract_name}{$contract_name}

=cut

sub count_hosts_percontract {
    my $dbh = shift;
    my %return_hash;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);

    foreach (@raw_hosts) {
        my %dbdata = %{$_};

        my $contract_name = $dbdata{'contract_name'};
        my $contract_id   = $dbdata{'contract_id'};
        my $state         = lc $dbdata{'status_state'};

        $return_hash{$contract_id}{$state}++;
        $return_hash{$contract_id}{'contract_name'} = $contract_name;

    }

    return \%return_hash;
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
