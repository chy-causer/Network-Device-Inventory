package Inventory::Status;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Status

=head1 VERSION

This document describes Inventory::Status version 1.01

=head1 SYNOPSIS

  use Inventory::Status;

=head1 DESCRIPTION

Handles data relating to the main status types for hosts in the database

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_status
  edit_status
  get_status_info
  count_states
  delete_states
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

Readonly my $MAX_NAME_LENGTH => '25';
Readonly my $MAX_DESC_LENGTH => '254';
Readonly my $ENTRY           => 'state';
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

=head2 create_status

Main creation sub.
  create_status($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic state name sanity.

=cut

sub create_status {
    my ( $dbh, $posts ) = @_;
    my %message;
    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (  !exists $posts->{'status_state'}
        || length( $posts->{'status_state'} ) < 1
        || length( $posts->{'status_state'} ) > $MAX_NAME_LENGTH
        || $posts->{'status_state'} =~ m/[^\w\s]/x )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    if ( exists $posts->{'status_description'} ) {
        $posts->{'status_description'} =~ s/[^\w\s]//gx;
        $posts->{'status_description'} = substr $posts->{'status_description'},
          0, $MAX_DESC_LENGTH;
    }
    else {
        $posts->{'status_description'} = 'none';
    }

    my $sth =
      $dbh->prepare('INSERT INTO status(state,description) VALUES(?,?)');

    if (
        !$sth->execute(
            $posts->{'status_state'},
            $posts->{'status_description'}
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_status

Main edit sub.
  edit_status ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Currently the only error check is for a missing database handle.

=cut

sub edit_status {
    my ( $dbh, $posts ) = @_;
    my %message;
    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'status_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    if (  !exists $posts->{'status_state'}
        || length( $posts->{'status_state'} ) < 1
        || length( $posts->{'status_state'} ) > $MAX_NAME_LENGTH
        || $posts->{'status_state'} =~ m/[^\w\s]/x )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    if ( exists $posts->{'status_description'} ) {
        $posts->{'status_description'} =~ s/[^\w\s]//gx;
        $posts->{'status_description'} = substr $posts->{'status_description'},
          0, $MAX_DESC_LENGTH;
    }
    else {
        $posts->{'status_description'} = 'none';
    }

    my $sth =
      $dbh->prepare('UPDATE status SET state=?,description=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'status_state'}, $posts->{'status_description'},
            $posts->{'status_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_status_info

Main individual record retrieval sub. 
 get_status_info ( $dbh, $status_id )

Returns the details in a hash.

=cut

sub get_status_info {
    my $dbh       = shift;
    my $status_id = shift;
    my $sth;

    return if !defined $dbh;

    if ( defined $status_id ) {
        $sth = $dbh->prepare(
            'SELECT id,state,description FROM status WHERE id=? ORDER BY state'
        );
        return if !$sth->execute($status_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT id,state,description FROM status ORDER BY state');
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 count_states

Count hosts per state

=cut

sub count_states {
    my $dbh = shift;
    my %message;
    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my @raw_data = Inventory::Hosts::get_hosts_info($dbh);
    my %return_hash;

    # cycle through the raw data
    # by group total up states
    foreach (@raw_data) {
        my %dbdata = %{$_};
        my $state  = $dbdata{'status_state'};

        $return_hash{$state}++;
    }

    return \%return_hash;
}

=pod

=head2 delete_states

Delete a single status

 delete_state( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_states {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM status WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
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
