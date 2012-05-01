package Inventory::HoststoContracts;
use strict;
use warnings;

our $VERSION = '1.00';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hoststocontracts
  get_hoststocontracts_info
  edit_hoststocontracts
  delete_hoststocontracts
);

use DBI;
use DBD::Pg;

sub create_hoststocontracts {
    my ( $dbh, $input ) = @_;
    my %message;

    my $sth = $dbh->prepare(
        'INSERT INTO 
                               hoststocontracts(host_id,contract_id)
                             VALUES(?,?)'
    );

    if ( !$sth->execute( $input->{'host_id'}, $input->{'contract_id'}, ) ) {
        $message{'ERROR'} =
          "Internal Error: The host to contract mapping was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The host to contract mapping was successful';
    return \%message;
}

sub edit_hoststocontracts {

    # similar to creating a contract except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;

    my $sth = $dbh->prepare(
        'UPDATE hoststocontracts SET host_id=?,contract_id=? WHERE id=?');

    if (
        !$sth->execute(
            $input->{'host_id'}, $input->{'contract_id'},
            $input->{'hosttocontract_id'},
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The host to contract mapping edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} =
      'Your host to contract mapping changes were commited successfully';
    return \%message;
}

sub delete_hoststocontracts {

    # delete a single hoststocontract

    my ( $dbh, $id ) = @_;
    my %message;

    my $sth = $dbh->prepare('DELETE FROM hoststocontracts WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The host to contract mapping could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
}

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

sub count_hosts_percontract {
    my $dbh = shift;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: List the database, things can only go downhill from here';
        return \%message;
    }

    my $sth;

    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);

    my %return_hash;

    # cycle through the raw data
    # by host total up occurances per model
    foreach (@raw_hosts) {
        my %dbdata = %{$_};

        my $model_name = $dbdata{'model_name'};
        my $model_id   = $dbdata{'model_id'};
        my $state      = lc $dbdata{'status_state'};

        # this isn't exactly pretty but it'll work
        $return_hash{$model_id}{$state}++;
        $return_hash{$model_id}{'model_name'} = $model_name;

    }

    return \%return_hash;
}

1;

__END__

=head1 NAME

Inventory::HoststoContracts - Manipulate HoststoContracts

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
