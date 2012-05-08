package Inventory::HoststoContracts;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::HoststoContracts

=head1 VERSION

This document describes Inventory::HoststoContracts version 1.01

=head1 SYNOPSIS

  use Inventory::HoststoContracts;

=head1 DESCRIPTION

Functions for dealing with the HoststoContracts table related data

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hoststocontracts
  get_hoststocontracts_info
  edit_hoststocontracts
  delete_hoststocontracts
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

Readonly my $ENTRY          => 'host to contract mapping';
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

=head2 create_hoststocontracts

Main creation sub.
  create_hoststocontracts($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and missing database ids.

=cut

sub create_hoststocontracts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $input->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }
    if ( !exists $input->{'contract_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    my $sth = $dbh->prepare(
        'INSERT INTO hoststocontracts(host_id,contract_id) VALUES(?,?)');

    if ( !$sth->execute( $input->{'host_id'}, $input->{'contract_id'}, ) ) {
        return {'ERROR'} => $MSG_CREATE_ERR;
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_hoststocontracts

Main edit sub.
  edit_hoststocontracts ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for a missing database handle and missing database ids.

=cut

sub edit_hoststocontracts {
    my ( $dbh, $input ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $input->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }
    if ( !exists $input->{'contract_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }
    if ( !exists $input->{'hosttocontract_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    my $sth = $dbh->prepare(
        'UPDATE hoststocontracts SET host_id=?,contract_id=? WHERE id=?');

    if (
        !$sth->execute(
            $input->{'host_id'}, $input->{'contract_id'},
            $input->{'hosttocontract_id'},
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 delete_hoststocontracts

Delete a single hoststocontracts link.

 delete_hoststocontracts( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_hoststocontracts {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM hoststocontracts WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 get_hoststocontracts_info

Main individual record retrieval sub. 
 get_hoststocontracts_info ( $dbh, $hoststocontracts_id )

Returns the details in a hash.

$hoststocontracts_id is optional, if not specified all results will be
returned.

Returns the details in a array of hashes.

=cut

sub get_hoststocontracts_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare( '
        SELECT 
           hoststocontracts.id,
           hoststocontracts.host_id,
           hoststocontracts.contract_id,
           hosts.name AS host_name,
           contracts.name AS contract_name

        FROM hoststocontracts 
            LEFT JOIN hosts on hosts.id = hoststocontracts.host_id
            LEFT JOIN contracts on contracts.id = hoststocontracts.contract_id
        
        WHERE 
           id=?
        
        ORDER BY 
           contracts.name
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare( '
        SELECT 
           hoststocontracts.id,
           hoststocontracts.host_id,
           hoststocontracts.contract_id,
           hosts.name AS host_name,
           contracts.name AS contract_name

        FROM hoststocontracts 
            LEFT JOIN hosts on hosts.id = hoststocontracts.host_id
            LEFT JOIN contracts on contracts.id = hoststocontracts.contract_id
        
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

=pod

=head2 count_hosts_percontract

Return all hosts associated indexed by contract

 count_hosts_percontract( $dbh )

Checks for missing database handle.

=cut

sub count_hosts_percontract {
    my $dbh = shift;

    return if !defined $dbh;

    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);

    my %return_hash;

    # cycle through the raw data
    # by host total up occurances per model
    foreach (@raw_hosts) {
        my %dbdata = %{$_};

        my $model_name = $dbdata{'model_name'};
        my $model_id   = $dbdata{'model_id'};
        my $state      = lc $dbdata{'status_state'};

        $return_hash{$model_id}{$state}++;
        $return_hash{$model_id}{'model_name'} = $model_name;

    }

    return \%return_hash;
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
