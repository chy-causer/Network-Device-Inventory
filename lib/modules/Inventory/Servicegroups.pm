#!/usr/bin/perl -T
#
# Name: Servicegroups.pm
# Creator: Guy Edwards
# Created: 2008-08-05
# Description: unknown
#
# $Id: Servicegroups.pm 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: gpGaljqrLLnSLh2iJpjq6ZIFh8jVSndT7yQDL1N98mg_o $
#
package Inventory::Servicegroups;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_servicegroups
  edit_servicegroups
  get_servicegroups_info
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;

sub create_servicegroups {
    my $dbh   = shift;
    my %posts = %{ shift() };

    my %message;
    if (   !exists $posts{'servicegroup_name'}
        || $posts{'servicegroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'servicegroup_name'} ) < 1
        || length( $posts{'servicegroup_name'} ) > 25 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = "Input Error: Check your input is correct";
        return \%message;
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
        $message{'ERROR'} =
          "Internal Error: The servicegroup creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = "The servicegroup creation was successful";
    return \%message;
}

sub edit_servicegroups {
    my $dbh   = shift;
    my %posts = %{ shift() };
    my %message;

    if (   !exists $posts{'servicegroup_id'}
        || $posts{'servicegroup_id'} =~ m/\D/x
        || !exists $posts{'servicegroup_name'}
        || $posts{'servicegroup_name'} =~ m/[^\w\s\.\-]/x
        || length( $posts{'servicegroup_name'} ) < 1
        || length( $posts{'servicegroup_name'} ) > 25 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = "Input Error: Check your input is correct";
        return \%message;
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
        $message{'ERROR'} =
          "Internal Error: The servicegroup edit was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = "Your changes were commited successfully";
    return \%message;
}

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

(c) Guy Edwards