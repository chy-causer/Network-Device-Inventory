package Inventory::Models;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Models

=head1 VERSION

This document describes Inventory::Models version 1.02

=head1 SYNOPSIS

  use Inventory::Models;

=head1 DESCRIPTION

Functions for dealing with the Model related data and analysis of it.

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_models
  edit_models
  get_models_info
  get_models_waps
  get_frodo_models
  count_hosts_permodel
  delete_models
  hosts_bymodel_id
  hosts_bymodel_name
  hash_hosts_permodel
  hosts_modeleol_thisyear
  hosts_modeleol
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
use Inventory::Hosts 1.01;

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

Readonly my $MAX_NAME_LENGTH => '45';
Readonly my $TIMEUNIT        => 'days';
Readonly my $ACTIVESTRING    => 'ACTIVE';

Readonly my $ENTRY           => 'model';
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

=head2 create_models

Main creation sub.
create_models($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

For the model name we strip leading and trailing whitespace to make life
easier for people pasting in model names from manufacturers websites and
similar.

Checks for a missing database handle and basic model name sanity.

=cut

sub create_models {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if ( exists $posts->{'model_name'} ) {
        $posts->{'model_name'} =~ s/[\s]+$//g;
        $posts->{'model_name'} =~ s/^[\s]+//g;
    }

    if (   !exists $posts->{'model_name'}
        || $posts->{'model_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'model_name'} ) < 1
        || length( $posts->{'model_name'} ) > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }
    
    # can't input "" as undef into postgres, it has to be a real undef
    if ( exists $posts->{'model_dateeol'}
        && length $posts->{'model_dateeol'} < 1 )
    {
        $posts->{'model_dateeol'} = undef;
    }

    my $sth = $dbh->prepare(
        'INSERT INTO models(name,manufacturer_id,dateeol) VALUES(?,?,?)');

    if (
        !$sth->execute(
            $posts->{'model_name'}, $posts->{'manufacturer_id'},
            $posts->{'model_dateeol'}
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_models

Main edit sub.
  edit_models ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

For the model name we strip leading and trailing whitespace to make life
easier for people pasting in model names from manufacturers websites and
similar.

Currently the only error check is for a missing database handle.

=cut

sub edit_models {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if ( exists $posts->{'model_name'} ) {
        $posts->{'model_name'} =~ s/[\s]+$//g;
        $posts->{'model_name'} =~ s/^[\s]+//g;
    }

    # can't input "" as undef into postgres, it has to be a real undef
    if ( exists $posts->{'model_dateeol'}
        && length $posts->{'model_dateeol'} < 1 )
    {
        $posts->{'model_dateeol'} = undef;
    }

    if (   !exists $posts->{'model_name'}
        || $posts->{'model_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'model_name'} ) < 1
        || length( $posts->{'model_name'} ) > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare(
        'UPDATE models SET name=?,manufacturer_id=?,dateeol=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'model_name'},    $posts->{'manufacturer_id'},
            $posts->{'model_dateeol'}, $posts->{'model_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_models_info

Main individual record retrieval sub. 
 get_models_info ( $dbh, $model_id )

Returns the details in a hash.

=cut

sub get_models_info {
    my ( $dbh, $model_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $model_id ) {
        $sth = $dbh->prepare(
            'SELECT 
           models.id,
           models.name,
           models.manufacturer_id,
           models.dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
           manufacturers.name AS manufacturer_name
        FROM models,manufacturers 
        WHERE
           models.manufacturer_id = manufacturers.id
           AND models.id=?
        ORDER BY 
           models.name
        '
        );
        return if !$sth->execute($TIMEUNIT,$TIMEUNIT,$model_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           models.id,
           models.name,
           models.manufacturer_id,
           models.dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
           manufacturers.name AS manufacturer_name
        FROM models,manufacturers 
        WHERE
           models.manufacturer_id = manufacturers.id
        ORDER BY 
           models.name
        '
        );
        return if !$sth->execute($TIMEUNIT,$TIMEUNIT);
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

=pod

=head2 count_hosts_permodel

Return total numers of hosts per model.

 count_hosts_permodel($dbh)

Returns a slightly complex has that includes state.

  %return{$model_id}
               {$state}{$number_of_hosts}
               {model_name}{$model_name}

=cut

sub count_hosts_permodel {
    my $dbh = shift;
    my %return_hash;

    # if ( !defined $dbh ) { return {'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $dbh ) { return; }

    my @raw_hosts = Inventory::Hosts::get_hosts_info($dbh);

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

=pod

=head2 get_frodo_models

Return all model types associated with the FroDo project

https://github.com/guyed/Network-Device-Inventory/issues/33
FIXME: 'Cisco', '3750' and similar values should be in a config file or
database table, not hardcoded. 

=cut

sub get_frodo_models {
    my $dbh = shift;
    my $sth;

    return if !defined $dbh;

    $sth = $dbh->prepare(
        'SELECT 
           models.id,
           models.name,
           models.manufacturer_id,
           models.dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
           manufacturers.name AS manufacturer_name
        FROM models
        LEFT JOIN manufacturers 
        ON
           models.manufacturer_id = manufacturers.id
        WHERE
           (
            manufacturers.name =?
            AND (
                models.name LIKE \'%3750%\'
                OR models.name LIKE \'%3560%\'
                OR models.name LIKE \'%224%\'
                OR models.name LIKE \'%2960%\'
                OR models.name LIKE \'%4948%\'
            )
           ) OR (
            manufacturers.name =?
           )
        ORDER BY 
           models.name
        '
    );
    return if !$sth->execute( $TIMEUNIT, $TIMEUNIT, 'Cisco', 'MGE' );

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

=pod

=head2 get_models_waps

Return all model types associated with the Wireless Access Points in the OWL
phase II project.

https://github.com/guyed/Network-Device-Inventory/issues/33
FIXME: 'Cisco', '3750' and similar values should be in a config file or
database table, not hardcoded. 

=cut

sub get_models_waps {
    my $dbh = shift;

    return if !defined $dbh;

    my $sth = $dbh->prepare(
        'SELECT 
           models.id,
           models.name,
           models.dateeol,
           models.manufacturer_id,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
           manufacturers.name AS manufacturer_name
        FROM models,manufacturers 
        WHERE
           models.manufacturer_id = manufacturers.id
           AND models.name ILIKE ?
        ORDER BY 
           models.name
        '
    );
    return if !$sth->execute($TIMEUNIT, $TIMEUNIT, '%AP1%');

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        next if $reference->{'name'} !~ m/^AP1\d{3}/;
        push @return_array, $reference;
    }

    return @return_array;
}

=pod

=head2 delete_models

Delete a single model.

 delete_models( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_models {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM models WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 hash_hosts_permodel

return all hosts indexed by model

 hash_hosts_permodel ($dbh, $optionalkey)

returns a hash

 hash_hosts_permodel ($dbh, 'id')
       $model_id => @hosts
 
 hash_hosts_permodel ($dbh)
       $model_id => @hosts

 hash_hosts_permodel ($dbh, 'name')
       $model_name => @hosts

where @hosts is an array of individual hashes, each has containing a hosts
data.

=cut

sub hash_hosts_permodel {
    my ($dbh,$key) = @_;

    return if !defined $dbh;
    if ( not defined $key
         or ( $key ne 'id' and $key ne 'name' )
        ){
      
       $key = 'id';
    }

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
           models.dateeol AS model_dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
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
    return if not $sth->execute( $TIMEUNIT, $TIMEUNIT );

    my %index;
    while ( my $ref = $sth->fetchrow_hashref ) {
        if ( !exists( $index{ $ref->{"model_$key"} } ) ) {
            my @data = ($ref);
            $index{ $ref->{"model_$key"} } = \@data;
        }
        else {
            push @{ $index{ $ref->{"model_$key"} } }, $ref;
        }
    }

    return \%index;
}

=pod

=head2 hosts_bymodel_name

Return all hosts for a given model (based on name).

  hosts_bymodel_name ( $dbh, $name )

Returns empty if either argument is missing.

Returns an array of hosts hashes if successful.

=cut

sub hosts_bymodel_name {
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
           models.dateeol AS model_dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
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
         
         WHERE models.name=?

         ORDER BY
           hosts.name
        ' );

    return if !$sth->execute($TIMEUNIT, $TIMEUNIT, $name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 hosts_bymodel_id

Return all hosts for a given model (based on id).

  hosts_bymodel_id ( $dbh, $id )

Returns empty if either argument is missing.

Returns an array of hosts hashes if successful.

=cut

sub hosts_bymodel_id {
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
           models.dateeol AS model_dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS dateeol_daysremaining,
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
         
         WHERE models.id=?

         ORDER BY
           hosts.name
        ' );

    return if !$sth->execute($TIMEUNIT, $TIMEUNIT, $id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 hosts_modeleol_thisyear

Return all hosts whose model type goes end of life within the next 365 days

=cut

sub hosts_modeleol_thisyear {
    my ( $dbh ) = @_;

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
           models.name AS model_name,
           models.dateeol AS model_dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS model_dateeol_daysremaining,
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
         
         WHERE ( date_part(?, date_trunc(?, (models.dateeol - now() ) ) )  > 0 )
         AND   ( date_part(?, date_trunc(?, (models.dateeol - now() ) ) ) < 365 )
         AND status.state=?

         ORDER BY
           hosts.name
        ' );

    return if !$sth->execute($TIMEUNIT,$TIMEUNIT,$TIMEUNIT, $TIMEUNIT, $TIMEUNIT, $TIMEUNIT, $ACTIVESTRING);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 hosts_modeleol

Return all hosts whose model type is already end of life

=cut

sub hosts_modeleol {
    my ( $dbh ) = @_;

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
           models.name AS model_name,
           models.dateeol AS model_dateeol,
           date_part(?, date_trunc(?, (models.dateeol -now()))) AS model_dateeol_daysremaining,
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
         
         WHERE ( date_part(?, date_trunc(?, (models.dateeol - now() ) ) ) < 1 )
         AND status.state=?

         ORDER BY
           hosts.name
        ' );

    return if !$sth->execute($TIMEUNIT,$TIMEUNIT,$TIMEUNIT,$TIMEUNIT,$ACTIVESTRING);

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
