package Inventory::Introlemembers;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Introlemembers

=head1 VERSION

This document describes Inventory::Introlemembers version 1.02

=head1 SYNOPSIS

  use Inventory::Introlemembers;

=head1 DESCRIPTION

Functions for dealing with the realationships of interfaces to hostgroups

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_memberships
  edit_memberships
  get_memberships_info
  count_memberships
  memberships_byinterfaceid
  memberships_byhostgroupid
  fqdns_bybashgroup
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

use Inventory::Introles 1.0;

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

Readonly my $ENTRY          => 'interface role membership';
Readonly my $MSG_DBH_ERR    => 'Internal Error: Lost the database connection';
Readonly my $MSG_INPUT_ERR  => "Please check your $ENTRY data input";
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

=head2 internal_checkinput

Attempt to put the input cleaning logic in one place

=cut

sub internal_checkinput {
    my $posts = shift;
    my @message_store;    # need to put all these messages somewhere

    # dont wave bad inputs at the database
    if (   !exists $posts->{'hostgroup_id'}
        || $posts->{'hostgroup_id'} =~ m/\D/x
        || length( $posts->{'hostgroup_id'} ) < 1 )
    {
        my %message;
        $message{'ERROR'} =
          'Input Error: The hostgroup_id supplied was non numeric';
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    if (   !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1 )
    {
        my %message;
        $message{'ERROR'} = 'Input Error: The host_id supplied was non numeric';
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    return @message_store;
}

=pod

=head2 delete_memberships

Delete a single host to a hostgroup relationship

 delete_membership( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_memberships {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM interfaces_to_introles WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 create_memberships

Main creation sub.
   create_memberships$dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle.

=cut

sub create_memberships {

    my ( $dbh, $posts ) = @_;

    # create a new entry of a host to a hostgroup

    # XXX XXX XXX
    # the posted host_id is actually an interface id since we switched to
    # linking roles to interfaces instead of hosts. also the hostgroup_id is
    # an interface_role id. sorry about that.
    # XXX XXX XXX

    # validate input
    my @message_store = internal_checkinput($posts);

    # catch calling errors
    if ( !$dbh ) {
        my %message;
        $message{'ERROR'} = $MSG_DBH_ERR;
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

    # should be an array of one item
    my @hosts_info =
      Inventory::Interfaces::get_interfaces_info( $dbh, $posts->{'host_id'} );
    my @groups_info =
      Inventory::Introles::get_hostgroups_info( $dbh,
        $posts->{'hostgroup_id'} );
    my %host_info  = %{ $hosts_info[0] };
    my %group_info = %{ $groups_info[0] };

    my $host_name  = $host_info{'host_name'};
    my $group_name = $group_info{'name'};

    my $sth = $dbh->prepare(
'INSERT INTO interfaces_to_introles (introle_id,interface_id) VALUES(?,?)'
    );

    if ( !$sth->execute( $posts->{'hostgroup_id'}, $posts->{'host_id'} ) ) {

        # find out what the error was
        my %message;
        my $full_error_string = $dbh->errstr;
        my $duplicate_entry_message =
          'duplicate key violates unique constraint';
        if ( $full_error_string =~ m/$duplicate_entry_message/ix ) {
            $message{'ERROR'} =
'Internal Error: You just tried to assign a role that the interface already has.';
        }
        else {
            $message{'ERROR'} = $MSG_CREATE_ERR;
        }
        push @message_store, \%message;
        return @message_store;
    }

    my %message;
    $message{'SUCCESS'} = $MSG_CREATE_OK;
    push @message_store, \%message;
    return @message_store;
}

=pod

=head2 edit_memberships

Main edit sub.
  edit_memberships ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for a missing database handle.

=cut

sub edit_memberships {
    my ( $dbh, $posts ) = @_;

    my @message_store = internal_checkinput($posts);

    if ( !$dbh ) {
        my %message;
        $message{'FATAL'} = $MSG_DBH_ERR;
        push @message_store, \%message;
    }

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

    if (   !exists $posts->{'membership_id'}
        || $posts->{'membership_id'} =~ m/\D/x
        || length $posts->{'membership_id'} < 1 )
    {
        my %message;
        $message{'FATAL'} = $MSG_INPUT_ERR;
        push @message_store, \%message;
        return @message_store;
    }

    my $sth = $dbh->prepare(
'UPDATE interfaces_to_introles SET introle_id = ?, interface_id = ?  WHERE id = ?'
    );
    if (
        !$sth->execute(
            $posts->{'hostgroup_id'}, $posts->{'host_id'},
            $posts->{'membership_id'}
        )
      )
    {

        # find out what the error was
        my $full_error_string = $dbh->errstr;
        my $duplicate_entry_message =
          'duplicate key violates unique constraint';
        my %message;
        if ( $full_error_string =~ m/$duplicate_entry_message/ix ) {
            $message{'ERROR'} =
'Input Error: You just tried to assign a role that the interface already has.';
        }
        else {
            $message{'ERROR'} = $MSG_EDIT_ERR;
        }
        push @message_store, \%message;
        return @message_store;
    }

    my %message;
    $message{'SUCCESS'} = $MSG_EDIT_OK;
    push @message_store, \%message;
    return @message_store;
}

=pod

=head2 memberships_byinterfaceid

Show all interface to host relationships related to a specific interface
  memberships_byinterfaceid ($dbh, $interface_id)

This should only ever return one entry but the subroutine can handle multiple
results if they do occur.

=cut

sub memberships_byinterfaceid {
    my $dbh          = shift;
    my $interface_id = shift;

    return if !$dbh;
    return if !$interface_id;

    my $sth = $dbh->prepare(
        'SELECT introle_id FROM interfaces_to_introles WHERE interface_id=?');

    # FIXME: we return error here but is it a useful way or returning? Can it
    # be improved?
    return 'ERROR' if !$sth->execute($interface_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %result = %{$reference};
        push @return_array, $result{'introle_id'};
    }
    return @return_array;
}

=pod

=head2 memberships_byhostgroupid

Show all interface to host relationships related to a specific interface role
  memberships_byhostgroupid ($dbh, $hostgroup_id)

=cut

sub memberships_byhostgroupid {
    my ( $dbh, $hostgroup_id ) = @_;

    return if !$dbh;
    return if !$hostgroup_id;

    my $sth = $dbh->prepare(
        'SELECT interface_id FROM interfaces_to_introles WHERE introle_id = ?');

    # FIXME: we return error here but is it a useful way or returning? Can it
    # be improved?
    return 'ERROR' if !$sth->execute($hostgroup_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %result = %{$reference};
        push @return_array, $result{'interface_id'};
    }
    return @return_array;
}

=pod

=head2 get_memberships_info

Main individual record retrieval sub. 
 get_memberships_info ( $dbh, $membership_id )

$membership_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

=cut

sub get_memberships_info {
    my ( $dbh, $membership_id ) = @_;
    my $sth;

    return if !$dbh;

    if ( defined $membership_id && $membership_id !~ m/\D/x ) {
        $sth = $dbh->prepare( '
        SELECT 
              interfaces_to_introles.id AS membership_id,
              interfaces_to_introles.introle_id AS hostgroup_id,
              interfaces_to_introles.interface_id AS host_id,
              introles.name AS hostgroup_name,
              introles.description AS hostgroup_description,
              interfaces.lastresolvedfqdn AS host_name,
              interfaces.address,
              status.state 
        FROM 
              interfaces_to_introles,
              interfaces, introles,
              hosts, status
        WHERE
              interfaces_to_introles.id=?, AND
                  interfaces_to_introles.introle_id = introles.id 
              AND interfaces_to_introles.interface_id = interfaces.id 
              AND interfaces.host_id = hosts.id
              AND hosts.status_id = status.id 
        ORDER BY
              introles.name,
              interfaces.lastresolvedfqdn
        ' );

        return if !$sth->execute($membership_id);
    }
    else {
        $sth = $dbh->prepare( '
        SELECT 
              interfaces_to_introles.id AS membership_id,
              interfaces_to_introles.introle_id AS hostgroup_id,
              interfaces_to_introles.interface_id AS host_id,
              introles.name AS hostgroup_name,
              introles.description AS hostgroup_description,
              interfaces.lastresolvedfqdn AS host_name,
              interfaces.address,
              status.state 
        FROM 
              interfaces_to_introles,
              interfaces, introles,
              hosts, status
        WHERE
                  interfaces_to_introles.introle_id = introles.id 
              AND interfaces_to_introles.interface_id = interfaces.id 
              AND interfaces.host_id = hosts.id
              AND hosts.status_id = status.id 
        ORDER BY
              introles.name,
              interfaces.lastresolvedfqdn
        ' );

        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 count_memberships

Main individual record retrieval sub. 
 count_memberships ( $dbh, $request )

$request is either 'group' or 'host'

Returns the totals in a hash.

=cut

sub count_memberships {
    my ( $dbh, $request ) = @_;
    my %message;

    # Test: are these messages visible?
    if ( !defined $dbh )     { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $request ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth;
    my @raw_data = Inventory::Introlemembers::get_memberships_info($dbh);

    my %return_hash;
    if ( $request eq 'group' ) {

        # cycle through the raw data
        # by group total up states
        foreach (@raw_data) {
            my %dbdata         = %{$_};
            my $hostgroup_name = $dbdata{'hostgroup_name'};
            my $state          = lc $dbdata{'state'};
            my $hostgroup_id   = $dbdata{'hostgroup_id'};

            $return_hash{$hostgroup_name}{$state}++;
            $return_hash{$hostgroup_name}{'hostgroup_id'} = $hostgroup_id;
        }
    }
    elsif ( $request eq 'host' ) {

        # cycle through the raw data
        # by group total up states
        foreach (@raw_data) {
            my %dbdata    = %{$_};
            my $host_name = $dbdata{'host_name'};
            my $host_id   = $dbdata{'host_id'};
            my $state     = lc $dbdata{'state'};

            # this isn't exactly pretty but it'll work
            $return_hash{$host_name}{$state}++;
            $return_hash{$host_name}{'host_id'} = $host_id;
        }
    }

    return \%return_hash;
}

=pod

=head2 fqdns_bybashgroup

This is the main function used for outputting a bash group
 fqdns_bybashgroup ( $dbh )

Outputs all the fully qualified domain names for each group that has a BASH
name entered.

Returns the totals in a hash.

=cut

sub fqdns_bybashgroup {

    my $dbh = shift;

    if ( !defined $dbh ) { return; }

    my @groups_info = Inventory::Introles::get_hostgroups_info($dbh);

    my %returnhash;

    foreach (@groups_info) {
        my %groupdata = %{$_};

        # dive out early if it's not marked as a bash group
        next
          if !exists $groupdata{'bash'}
              || !defined $groupdata{'bash'}
              || length( $groupdata{'bash'} ) < 1;
        my $bashname = $groupdata{'bash'};
        my $group_id = $groupdata{'id'};

        # 1. we want to find all hosts in this group
        # 2. and we want to know all these hosts fqdns
        # 3. we dont care which hosts have which fqdns
        # 4. we dont want duplicate fqdns in a groups

        my $sth = $dbh->prepare(
            q{
        SELECT 
            int2.lastresolvedfqdn
        FROM interfaces AS int1
            LEFT JOIN interfaces_to_introles ON int1.id = interfaces_to_introles.interface_id
            LEFT JOIN introles ON introles.id = interfaces_to_introles.introle_id
            LEFT JOIN hosts ON int1.host_id = hosts.id
            LEFT JOIN status ON hosts.status_id = status.id
            LEFT JOIN interfaces AS int2 ON int1.host_id = int2.host_id
        WHERE
            introles.bash = ?
            AND status.state IN ('ACTIVE','INACTIVE')
            AND int2.isprimary = true;
       }
        );

        # if it goes wrong once it'll go wrong many times
        # hence 'return' not 'next'
        return if !$sth->execute($bashname);

        # load existing array so bash name can be shared
        my @array_of_fqdns = @{ $returnhash{$bashname} || [] };

        while ( my $reference = $sth->fetchrow_hashref ) {
            push @array_of_fqdns, $reference->{'lastresolvedfqdn'};
        }

        # so we have an array of fqdns, now linked to the hostgroup
        $returnhash{$bashname} = \@array_of_fqdns;
    }

    # need to remove dupes from each list
    foreach my $b ( keys %returnhash ) {
        my @dupe_list    = @{ $returnhash{$b} };
        my %uniqify_hash = ();
        ++$uniqify_hash{$_} for @dupe_list;
        $returnhash{$b} = [ keys %uniqify_hash ];
    }

    return \%returnhash;
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
