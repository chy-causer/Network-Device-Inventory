package Inventory::Introles;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Introles

=head1 VERSION

This document describes Inventory::Introles version 1.01

=head1 SYNOPSIS

  use Inventory::Introles;

=head1 DESCRIPTION

Module for manipulating the interface to interface role information

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hostgroups
  edit_hostgroups
  get_hostgroups_info
);

use DBI;
use DBD::Pg;

my $ENTRY          = 'interface role';
my $MSG_DBH_ERR    = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR  = 'Input Error: Please check your input';
my $MSG_CREATE_OK  = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK    = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR   = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK  = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR  = 'The error was fatal, processing stopped';

=pod

=head1 SUBROUTINES

=cut

sub create_hostgroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $posts{'hostgroup_name'}
        || $posts{'hostgroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'hostgroup_name'} ) < 1
        || length( $posts{'hostgroup_name'} ) > 25 )
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
        || length( $posts{'hostgroup_name'} ) > 25 )
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

1;
__END__



=head2 Returns
 All returns from lists are arrays of hashes

 All creates and edits return a hash, the key gives success or failure, the
 value gives the human message of what went wrong.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected is required.
Other configuration is at the application level via a configuration file, but
the module is only passed the database handle.

=head1 DEPENDENCIES

DBI
DBD::Pg

=head1 INCOMPATIBILITIES

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
