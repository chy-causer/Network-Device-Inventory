# $Id: Introles.pm 3526 2012-02-07 11:54:05Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-07 11:54:05 +0000 (Tue, 07 Feb 2012) $
# $LastChangedRevision: 3526 $
package Inventory::Introles;
use strict;
use warnings;

use version; our $VERSION = qv('0.0.1');
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
        'INSERT INTO introles (name,bash,nagios,description) VALUES(?,?,?,?)');

    if (
        !$sth->execute(
            $posts{'hostgroup_name'},   $posts{'hostgroup_bash'},
            $posts{'hostgroup_nagios'}, $posts{'hostgroup_description'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The Interface Role creation was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'The Interface Role creation was successful';
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
        'UPDATE introles SET name=?,bash=?,nagios=?,description=? WHERE id=?');
    if (
        !$sth->execute(
            $posts{'hostgroup_name'},   $posts{'hostgroup_bash'},
            $posts{'hostgroup_nagios'}, $posts{'hostgroup_description'},
            $posts{'hostgroup_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The Interface Role edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} =
      'Your interface role changes were commited successfully';
    return \%message;
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

=head1 BUGS AND LIMITATIONS

Probably tonnes

=head1 AUTHOR

Guy Edwards guyjohnedwards@gmail.com