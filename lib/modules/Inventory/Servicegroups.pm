package Inventory::Servicegroups;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Servicegroups

=head1 VERSION

This document describes Inventory::Servicegroups version 1.02

=head1 SYNOPSIS

  use Inventory::Servicegroups;

=head1 DESCRIPTION

Module to handle the data relating to servicegroups.

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_servicegroups
  edit_servicegroups
  get_servicegroups_info
  delete_servicegroups
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

Readonly my $ENTRY           => 'servicegroup';
Readonly my $MAX_NAME_LENGTH => '25';

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

=head2 create_servicegroups

Main creation sub.
 create_servicegroups($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic servicegroup details sanity.

=cut

sub create_servicegroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $posts{'servicegroup_name'}
        || $posts{'servicegroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'servicegroup_name'} ) < 1
        || length( $posts{'servicegroup_name'} ) > $MAX_NAME_LENGTH )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    if ( exists $posts{'servicegroup_bash'} ) {
        $posts{'servicegroup_bash'} =~ s/\W//gx;
        $posts{'servicegroup_bash'} = uc $posts{'servicegroup_bash'};
    }
    if ( exists $posts{'servicegroup_description'} ) {
        $posts{'servicegroup_description'} =~ s/[^\w\s\.\-]//gx;
    }
    if ( exists $posts{'servicegroup_nagios'} ) {
        $posts{'servicegroup_nagios'} =~ s/[^\w\s\-]//gx;
    }

    # empty != undef in SQL world - we need to avoid duplicate blank fields
    $posts{'servicegroup_bash'}        ||= undef;
    $posts{'servicegroup_nagios'}      ||= undef;
    $posts{'servicegroup_description'} ||= undef;

    my $sth = $dbh->prepare(
'INSERT INTO servicegroups(name,bash,nagios,description) VALUES(?,?,?,?)'
    );

    if (
        !$sth->execute(
            $posts{'servicegroup_name'},   $posts{'servicegroup_bash'},
            $posts{'servicegroup_nagios'}, $posts{'servicegroup_description'}
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_servicegroups

Main edit sub.
  edit_servicegroups ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for a missing database handle and basic servicegroup details sanity.

=cut

sub edit_servicegroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'servicegroup_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    if (   !exists $posts{'servicegroup_name'}
        || $posts{'servicegroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'servicegroup_name'} ) < 1
        || length( $posts{'servicegroup_name'} ) > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    # alphanumeric upper case only, forced
    $posts{'servicegroup_bash'}   =~ s/\W//gx;
    $posts{'servicegroup_nagios'} =~ s/[^\w\s\-]//gx;
    $posts{'servicegroup_bash'} = uc $posts{'servicegroup_bash'};

    # alphanumeric only, forced
    $posts{'servicegroup_description'} =~ s/[^\w\s\.\-]//gx;

    # empty != undef in SQL world - we need to avoid duplicate blank fields
    $posts{'servicegroup_bash'}        ||= undef;
    $posts{'servicegroup_nagios'}      ||= undef;
    $posts{'servicegroup_description'} ||= undef;

    my $sth = $dbh->prepare(
'UPDATE servicegroups SET name=?,bash=?,nagios=?,description=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $posts{'servicegroup_name'},   $posts{'servicegroup_bash'},
            $posts{'servicegroup_nagios'}, $posts{'servicegroup_description'},
            $posts{'servicegroup_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_DBH_OK };
}

=pod

=head2 get_servicegroups_info

Main individual record retrieval sub. 
 get_servicegroups_info ( $dbh, $servicegroup_id, $orderby, $direction )

$servicegroup_id is optional, if not specified all results will be returned.

Sorting logic is optional and is about to be removed
https://github.com/guyed/Network-Device-Inventory/issues/51

Returns the details in a array of hashes.

=cut

sub get_servicegroups_info {
    my $dbh             = shift;
    my $servicegroup_id = shift;
    my $orderby         = shift;
    my $direction       = shift;
    my $sth;

    return if !defined $dbh;

    # hack attacks -> bin
    if (
        !defined $orderby
        || (   $orderby ne 'name'
            && $orderby ne 'bash'
            && $orderby ne 'nagios' )
      )
    {
        $orderby = 'name';
    }
    if ( !defined $direction
        || ( $direction ne 'asc' && $direction ne 'desc' ) )
    {
        $direction = 'asc';
    }

    # all set
    if ( defined $servicegroup_id && length($servicegroup_id) > 0 ) {
        $sth = $dbh->prepare(
'SELECT id,name,description,bash,nagios FROM servicegroups WHERE id=? ORDER BY ? , ?'
        );
        return if !$sth->execute( $servicegroup_id, $orderby, $direction );
    }
    else {
        $sth = $dbh->prepare(
'SELECT id,name,description,bash,nagios FROM servicegroups ORDER BY ? , ?'
        );
        return if !$sth->execute( $orderby, $direction );
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %results = %{$reference};
        push @return_array, \%results;
    }

    return @return_array;
}

=pod

=head2 delete_servicegroups

Delete a single servicegroup.

 delete_servicegroups( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_servicegroups {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM servicegroups WHERE id=?');
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
