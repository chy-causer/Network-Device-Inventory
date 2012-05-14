package Inventory::Locations;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Locations

=head1 VERSION

This document describes Inventory::Locations version 1.01

=head1 SYNOPSIS

  use Inventory::Locations;

=head1 DESCRIPTION

Functions for dealing with the locations data and analysis of it.

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_locations
  edit_locations
  get_locations_info
  count_locations_perhost
  delete_locations
  hash_hosts_perlocation
  hosts_bylocation_name
  hosts_bylocation_id
);

=pod

=head1 DEPENDENCIES

DBI
DBD::Pg
Readonly
Inventory::Hosts 1.01

=cut

use DBI;
use DBD::Pg;
use Readonly;
use Inventory::Hosts 1.0;

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

Readonly my $ENTRY          => 'location';
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

=head1 SUBROUTINES/METHODS

=head2 create_locations

Main creation sub.
  create_locations($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Currently the only error check is for a missing database handle.

=cut

sub create_locations {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my $sth = $dbh->prepare('INSERT INTO locations(name) VALUES(?)');

    if ( !$sth->execute( $posts->{'location_name'} ) ) {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_locations

Main edit sub.
  edit_locations ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Currently the only error check is for a missing database handle.

=cut

sub edit_locations {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my $sth = $dbh->prepare('UPDATE locations SET name=? WHERE id=?');
    if ( !$sth->execute( $posts->{'location_name'}, $posts->{'location_id'} ) )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_locations_info

Main individual record retrieval sub. 
 get_locations_info ( $dbh, $location_id )

Returns the details in a hash.

=cut

sub get_locations_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT id,name FROM locations WHERE id=? ORDER BY name');
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare('SELECT id,name FROM locations ORDER BY name');
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 count_hosts_perlocation

Return total numers of hosts per location.

 count_hosts_perlocation($dbh)

Returns a slightly complex has that includes state.

  %return{$location_id}
               {$state}{$number_of_hosts}
               {location_name}{$location_name}

=cut

sub count_hosts_perlocation {
    my $dbh = shift;
    my %return_hash;

    if ( !defined $dbh ) {
        return;
    }

    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);

    foreach (@raw_hosts) {
        my %dbdata        = %{$_};
        my $location_name = $dbdata{'location_name'};
        my $location_id   = $dbdata{'location_id'};

        my $state = lc $dbdata{'status_state'};
        $return_hash{$location_id}{$state}++;
        $return_hash{$location_id}{'location_name'} = $location_name;
    }
    return \%return_hash;
}

=pod

=head2 delete_locations

Delete a single location.

 delete_locations( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_locations {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM locations WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 hash_hosts_perlocation

return all hosts indexed by location

 hash_hosts_perlocation ($dbh)

returns a hash

 $location_name => @hosts

where @ hosts is an array of individual hashes, each has containing a hosts
data.

=cut

sub hash_hosts_perlocation {
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
         
         ORDER BY
           hosts.name
        
        ' );
    return if not $sth->execute();

    my %index;
    while ( my $ref = $sth->fetchrow_hashref ) {
        if ( !exists( $index{ $ref->{'location_id'} } ) ) {
            my @data = ($ref);
            $index{ $ref->{'location_id'} } = \@data;
        }
        else {
            push @{ $index{ $ref->{'location_id'} } }, $ref;
        }
    }

    return \%index;
}

=pod

=head2 hosts_bylocation_name

Return all hosts for a given location (based on name).

  hosts_bylocation_name ( $dbh, $name )

Returns empty if either argument is missing.

Returns an array of hosts hashes if successful.

=cut

sub hosts_bylocation_name {
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
           locations.id AS location_id,
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
         
         WHERE locations.name=?

         ORDER BY
           hosts.name
        ' );

    return if not $sth->execute($name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;

}

=pod

=head2 hosts_bylocation_id

Return all hosts for a given location (based on id).

  hosts_bylocation_id ( $dbh, $id )

Returns empty if either argument is missing.

Returns an array of hosts hashes if successful.

=cut

sub hosts_bylocation_id {
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
           locations.id AS location_id,
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
         
         WHERE locations.id=?

         ORDER BY
           hosts.name
        ' );

    return if not $sth->execute($name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;

}

1;
__END__

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
