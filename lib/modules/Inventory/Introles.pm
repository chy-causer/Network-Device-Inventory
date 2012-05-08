package Inventory::Introles;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Introles

=head1 VERSION

This document describes Inventory::Introles version 1.02

=head1 SYNOPSIS

  use Inventory::Introles;

=head1 DESCRIPTION

Module for manipulating the interface to interface role information

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hostgroups
  edit_hostgroups
  get_hostgroups_info
  delete_hostgroups
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

Readonly my $ENTRY           => 'interface role';
Readonly my $MAX_NAME_LENGTH => '30';

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

=head2 create_hostgroups

Main creation sub.
create_hostgroups($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic XXX name sanity.

=cut

sub create_hostgroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $posts{'hostgroup_name'}
        || $posts{'hostgroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'hostgroup_name'} ) < 1
        || length( $posts{'hostgroup_name'} ) > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    if ( exists $posts{'hostgroup_bash'} ) {
        $posts{'hostgroup_bash'} =~ s/\W//gx;
        $posts{'hostgroup_bash'} = uc $posts{'hostgroup_bash'};
    }
    if ( exists $posts{'hostgroup_description'} ) {
        $posts{'hostgroup_description'} =~ s/[^\w\s\.\-]//gx;
    }
    if ( exists $posts{'hostgroup_nagios'} ) {
        $posts{'hostgroup_nagios'} =~ s/[^\w\s\-]//gx;
    }

    $posts{'hostgroup_bash'}        ||= undef;
    $posts{'hostgroup_nagios'}      ||= undef;
    $posts{'hostgroup_description'} ||= undef;

    my $sth = $dbh->prepare(
        'INSERT INTO introles (name,bash,nagios,description) VALUES(?,?,?,?)');

    if (
        !$sth->execute(
            $posts{'hostgroup_name'},   $posts{'hostgroup_bash'},
            $posts{'hostgroup_nagios'}, $posts{'hostgroup_description'}
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_hostgroups

Main edit sub.
  edit_hostgroups ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for broken database handle and various input sanity checks

=cut

sub edit_hostgroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts{'hostgroup_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }

    if (   !exists $posts{'hostgroup_name'}
        || $posts{'hostgroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'hostgroup_name'} ) < 1
        || length( $posts{'hostgroup_name'} ) > $MAX_NAME_LENGTH )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    # alphanumeric upper case only, forced
    $posts{'hostgroup_bash'}   =~ s/\W//gx;
    $posts{'hostgroup_nagios'} =~ s/[^\w\s\-]//gx;
    $posts{'hostgroup_bash'} = uc $posts{'hostgroup_bash'};
    $posts{'hostgroup_bash'}   ||= undef;
    $posts{'hostgroup_nagios'} ||= undef;

    # alphanumeric only, forced
    $posts{'hostgroup_description'} =~ s/[^\w\s\.\-]//gx;

    my $sth = $dbh->prepare(
        'UPDATE introles SET name=?,bash=?,nagios=?,description=? WHERE id=?');
    if (
        !$sth->execute(
            $posts{'hostgroup_name'},   $posts{'hostgroup_bash'},
            $posts{'hostgroup_nagios'}, $posts{'hostgroup_description'},
            $posts{'hostgroup_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_hostgroups_info

Main individual record retrieval sub. 
 get_hostgroups_info ( $dbh, $hostgroup_id )

$hostgroup_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

Sorting logic is scheduled to be removed
https://github.com/guyed/Network-Device-Inventory/issues/49

=cut

sub get_hostgroups_info {
    my $dbh          = shift;
    my $hostgroup_id = shift;
    my $orderby      = shift;
    my $direction    = shift;
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
    if ( defined $hostgroup_id && length($hostgroup_id) > 0 ) {

        $sth = $dbh->prepare(
'SELECT id,name,description,bash,nagios FROM introles WHERE id=? ORDER BY ?, ?'
        );    # XXX Broken order by and sort
        return if !$sth->execute( $hostgroup_id, $orderby, $direction );
    }
    else {
        $sth = $dbh->prepare(
'SELECT id,name,description,bash,nagios FROM introles ORDER BY name ASC'
        );
        return if !$sth->execute;
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %results = %{$reference};

        # I was having some problems, alright?
        push @return_array, \%results;
    }

    return @return_array;
}

=pod

=head2 delete_hostgroups

Delete a single model.

 delete_hostgroups( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_hostgroups {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM introles WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 hash_hosts_permodel

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
