package Inventory::Hostgroups;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hostgroups
  edit_hostgroups
  get_hostgroups_info
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;

sub create_hostgroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    my %message;
    if (   !exists $posts{'hostgroup_name'}
        || $posts{'hostgroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'hostgroup_name'} ) < 1
        || length( $posts{'hostgroup_name'} ) > 25 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = 'Input Error: Check your input is correct';
        return \%message;
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
        'INSERT INTO hostgroups(name,bash,nagios,description) VALUES(?,?,?,?)'
    );

    if (
        !$sth->execute(
            $posts{'hostgroup_name'},   $posts{'hostgroup_bash'},
            $posts{'hostgroup_nagios'}, $posts{'hostgroup_description'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The hostgroup creation was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'The hostgroup creation was successful';
    return \%message;
}

sub edit_hostgroups {
    my $dbh   = shift;
    my %posts = %{ shift() };
    my %message;

    if (   !exists $posts{'hostgroup_id'}
        || $posts{'hostgroup_id'} =~ m/\D/x
        || !exists $posts{'hostgroup_name'}
        || $posts{'hostgroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'hostgroup_name'} ) < 1
        || length( $posts{'hostgroup_name'} ) > 25 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = 'Input Error: Check your input is correct';
        return \%message;
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
        'UPDATE hostgroups SET name=?,bash=?,nagios=?,description=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $posts{'hostgroup_name'},   $posts{'hostgroup_bash'},
            $posts{'hostgroup_nagios'}, $posts{'hostgroup_description'},
            $posts{'hostgroup_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The hostgroup edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your changes were commited successfully';
    return \%message;
}

sub get_hostgroups_info {
    my ( $dbh, $hostgroup_id, $orderby, $direction ) = @_;
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
'SELECT id,name,description,bash,nagios FROM hostgroups WHERE id=? ORDER BY ? , ?'
        );
        return if !$sth->execute( $hostgroup_id, $orderby, $direction );
    }
    else {
        $sth = $dbh->prepare(
'SELECT id,name,description,bash,nagios FROM hostgroups ORDER BY ? , ?'
        );
        return if !$sth->execute( $orderby, $direction );
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

=head1 NAME

Inventory - Networks team inventory module

=head2 VERSION

This document describes Inventory version 0.0.1

=head1 SYNOPSIS

  use Inventory;

=head1 DESCRIPTION

=head2 Main Subroutines

 The main abilities are:
  - create new types of entry in a table
  - edit existing entries in a table
  - list existing entries

=head2 Returns
 All returns from lists are arrays of hashes

 All creates and edits return a hash, the key gives success or failure, the value gives the human message of what went wrong.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected is required. Other configuration is at the application level via a configuration file, but the module is only passed the database handle.

=head1 DEPENDENCIES

Since I'm talking to a postgres database
DBI
DBD::Pg

...and for sanity/consistency...
Regexp::Common

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
