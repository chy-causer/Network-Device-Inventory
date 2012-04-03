package Inventory::Models;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_models
  edit_models
  get_models_info
  get_models_waps
  get_frodo_models
  count_hosts_permodel
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;
use Inventory::Hosts qw(get_hosts_info);

sub create_models {

    # respond to a request to create a model
    # 1. validate input
    # 2. make the database entry
    # 3. return success or fail
    #
    my ( $dbh, $posts ) = @_;

    my %message;

    if (
           !exists $posts->{'model_name'}
        || $posts->{'model_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'model_name'} ) < 1
        || length( $posts->{'model_name'} ) > 35

        || !exists $posts->{'manufacturer_id'}
        || $posts->{'manufacturer_id'} =~ m/\D/x
        || length( $posts->{'manufacturer_id'} ) < 1
      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth =
      $dbh->prepare('INSERT INTO models(name,manufacturer_id,dateeol) VALUES(?,?,?)');

    if ( !$sth->execute( $posts->{'model_name'}, $posts->{'manufacturer_id'}, $posts->{'model_dateeol'} ) )
    {
        $message{'ERROR'} =
          "Internal Error: The model creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The model creation was successful';
    return \%message;
}

sub edit_models {

    # similar to creating a model
    # except we already (should) have a vaild database id
    # for the entry
    #
    my ( $dbh, $posts ) = @_;

    my %message;

    if (   !exists $posts->{'model_name'}
        || $posts->{'model_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'model_name'} ) < 1
        || length( $posts->{'model_name'} ) > 35
        || !exists $posts->{'manufacturer_id'}
        || $posts->{'manufacturer_id'} =~ m/\D/x
        || length( $posts->{'manufacturer_id'} ) < 1
        || !exists $posts->{'model_id'}
        || $posts->{'model_id'} =~ m/\D/x
        || length( $posts->{'model_id'} ) < 1 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth =
      $dbh->prepare('UPDATE models SET name=?,manufacturer_id=?,dateeol=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'model_name'}, $posts->{'manufacturer_id'},
            $posts->{'model_dateeol'}, $posts->{'model_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The model entry edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your model changes were commited successfully';
    return \%message;
}

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
           manufacturers.name AS manufacturer_name
        FROM models,manufacturers 
        WHERE
           models.manufacturer_id = manufacturers.id
           AND models.id=?
        ORDER BY 
           models.name
        '
        );
        return if !$sth->execute($model_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           models.id,
           models.name,
           models.manufacturer_id,
           models.dateeol,
           manufacturers.name AS manufacturer_name
        FROM models,manufacturers 
        WHERE
           models.manufacturer_id = manufacturers.id
        ORDER BY 
           models.name
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

sub count_hosts_permodel {
    my $dbh = shift;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
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

sub get_frodo_models {
    my $dbh = shift;
    my $sth;

    #  FIXME: Cisco and 3750 should be in a config file
    return if !defined $dbh;

    $sth = $dbh->prepare(
        'SELECT 
           models.id,
           models.name,
           models.manufacturer_id,
           models.dateeol,
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
    return if !$sth->execute( 'Cisco', 'MGE' );

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

sub get_models_waps {
    my $dbh = shift;

    return if !defined $dbh;

    my $sth = $dbh->prepare(
        'SELECT 
           models.id,
           models.name,
           models.dateeol,
           models.manufacturer_id,
           manufacturers.name AS manufacturer_name
        FROM models,manufacturers 
        WHERE
           models.manufacturer_id = manufacturers.id
           AND models.name ILIKE ?
        ORDER BY 
           models.name
        '
    );
    return if !$sth->execute('%AP1%');

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        next if $reference->{'name'} !~ m/^AP1\d{3}/;
        push @return_array, $reference;
    }

    return @return_array;
}

1;
__END__

=pod

=head1 NAME

Inventory::Models - Information on Models

=head2 VERSION

This document describes Inventory::Models version 1.0.1

=head1 SYNOPSIS

  use Inventory::Models;

=head1 PURPOSE

If you wish to investigate what models exist in the database or want to
investigate how popular each model is, then this module assists in that
process. A subroutine is provided for each of: creating, editing, listing all
entries, and listing summary totals of the relationships.

=head1 DESCRIPTION

The module aims to hide the tasks of raw SQL queries to the database from wou
when performing common tasks which involve the relationhips of models to hosts
in the inventory table.

The data returned from a query should be generous, as well as the ids of the
models involved the names, statuses and similar are available. Each subroutine
should also give a descriptive success or failure message.

=head2 Main Subroutines

=head3 create_models($dbh,$hashref)

$dbh is the database handle for the Inventory Database

This subrouting will always return a hashref with the SUCCESS or ERROR state recorded in the hash key and the human description recorded in the hash keys value, e.g.
$message{'SUCCESS'} = 'Your changes were commited successfully';

=head3 edit_models($dbh,$hashref)
=head3 list_models_info($dbh,$optional_manufacturersid)
=head3 count_hosts_permodel($dbh)

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected by the overall
Inventory module is required. Other configuration is at the application level
via a configuration file loaded via Config::Tiny in the calling script, but
this module itself is only passed the resulting database handle.

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Inventory;
Inventory::Hosts;

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
