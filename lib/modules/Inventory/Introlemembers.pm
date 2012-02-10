# $Id: Introlemembers.pm 3535 2012-02-10 12:47:01Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-10 12:47:01 +0000 (Fri, 10 Feb 2012) $
# $LastChangedRevision: 3535 $
package Inventory::Introlemembers;
use strict;
use warnings;

use version; our $VERSION = qv('0.0.1');
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

use DBI;
use DBD::Pg;
use Inventory::Interfaces;
use Inventory::Introles;

sub internal_checkinput {
    my $posts = @_;
    my @message_store;    # need to put all these messages somewhere

    # dont wave bad inputs at the database
    if (   !exists $posts->{'hostgroup_id'}
        || $posts->{'hostgroup_id'} =~ m/\D/x
        || length( $posts->{'hostgroup_id'} ) < 1 )
    {
        my %message;
        $message{'ERROR'} =
          'Input Error: The hostgroup_id supplied was non numeric';
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
    }

    if (   !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1 )
    {
        my %message;
        $message{'ERROR'} = 'Input Error: The host_id supplied was non numeric';
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
    }

    return @message_store;
}

sub delete_memberships {

    # delete an existing entry of a host to a hostgroup
    my ( $dbh, $posts ) = @_;
    my @message_store;    # need to put all these messages somewhere

    # catch calling errors
    if ( !$dbh ) {
        my %message;
        $message{'ERROR'} =
'Internal Error: The database died or otherwise vanished before I could add the entry';
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
        return @message_store;
    }

    # dump bad inputs
    if (   !exists $posts->{'membership_id'}
        || $posts->{'membership_id'} =~ m/\D/x
        || length $posts->{'membership_id'} < 1 )
    {
        my %message;
        $message{'ERROR'} =
          'Input Error: The membership_id supplied was non numeric';
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
        return @message_store;
    }

    my $sth = $dbh->prepare('DELETE FROM interfaces_to_introles WHERE id = ?');
    if ( !$sth->execute( $posts->{'membership_id'} ) ) {
        my %message;
        $message{'ERROR'} = 'Internal Error: The delete was unsuccessful';
        push @message_store, \%message;
        return @message_store;
    }

    my %message;
    $message{'SUCCESS'} =
      'Your interface role membership delete was commited successfully';
    push @message_store, \%message;

    return @message_store;
}

sub create_memberships {

    my ( $dbh, $posts ) = @_;

    # create a new entry of a host to a hostgroup

    # XXX XXX XXX
    # the host_id is actually an interface id since we switched to linking
    # roles to interfaces instead of hosts. also the hostgroup_id is an
    # interface_role id. sorry about that.
    # XXX XXX XXX

    # validate input
    my @message_store = internal_checkinput($posts);

    # catch calling errors
    if ( !$dbh ) {
        my %message;
        $message{'FATAL'} =
'Internal Error: The database died or otherwise vanished before I could add the entry';
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

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
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
            $message{'ERROR'} =
'Internal Error: The Interface Role Membership creation was unsuccessful.';
        }
        push @message_store, \%message;
        return @message_store;
    }

    my %message;
    $message{'SUCCESS'} =
"The Interface Role Membership creation was successful: $host_name now has the $group_name role";
    push @message_store, \%message;
    return @message_store;
}

sub edit_memberships {
    my ( $dbh, $posts ) = @_;

    # validate input
    my @message_store = internal_checkinput($posts);

    # catch calling errors
    if ( !$dbh ) {
        my %message;
        $message{'FATAL'} =
'Internal Error: The database died or otherwise vanished before I could edit the entry';
        push @message_store, \%message;
    }

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

    # dump bad inputs
    if (   !exists $posts->{'membership_id'}
        || $posts->{'membership_id'} =~ m/\D/x
        || length $posts->{'membership_id'} < 1 )
    {
        my %message;
        $message{'FATAL'} =
          'Input Error: The membership_id supplied was non numeric';
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
            $message{'ERROR'} =
'Internal Error: The Interface Role Membership edit was unsuccessful';
        }
        push @message_store, \%message;
        return @message_store;
    }

    my %message;
    $message{'SUCCESS'} =
      'Your interface role membership changes were commited successfully';
    push @message_store, \%message;
    return @message_store;
}

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

sub count_memberships {
    my ( $dbh, $request ) = @_;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
        return \%message;
    }
    if ( !defined $request ) {
        $message{'ERROR'} =
'Internal Error: There is a programming error in a call to Inventory::Introlemembers::count_memberships';
        return \%message;
    }

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

sub fqdns_bybashgroup {

    # this is the main function used for making a bash group
    my $dbh = shift;

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

    # I can't believe this funcion came together so easily
    # You are surrounded by a golden glow
    # You spot a four leaf clover at your feet
    return \%returnhash;
}

1;
__END__

=head1 NAME

Inventory::Memberships - Realationships of hosts to hostgroups

=head2 VERSION

This document describes Inventory::Memberships version 0.0.1

=head1 SYNOPSIS

  use Inventory::Memberships;
  # There are no special setup requirements

=head1 PURPOSE

If you wish to investigate what groups a host is in: or conversly to discover what hosts are in a hostgroup, then this module assists in that process. A subroutine is procided for each of: creating, editing, listing all entries, and listing summary totals of the relationships.

=head1 DESCRIPTION

The module aims to hide the tasks of raw SQL queries to the dayabase from wou
when performing common tasks which involve the relationhips of hosts to
hostgroups in the inventory table.

The data returned from a query should be generous, as well as the ids of the
hosts involothe names, statuses and similar are returned. Each subroutine
should also give a descriptive success or failure message.

=head2 Main Subroutines

=head3 create_memberships($dbh,$hashref)

$dbh is the database handle for the Inventory Database
$hashref is a hash of values, usually as a result of the user submitting a form, e.g. your %POST values. The hash must contain the following keys with values for a successful creation of a host to hostgroup mapping:
$hash{'hostgroup_id'}
$hash{'host_id'}
Other values can exist in the hash without conflict or other issues.
    
This subrouting will always return a hashref with the SUCCESS or ERROR state recorded in the hash key and the human description recorded in the hash keys value, e.g.
$message{'SUCCESS'} = 'Your changes were commited successfully';


=head3 edit_memberships($dbh,$hashref)

The edit subroutine is very similar to the create in usage, although the purpose can only be to edit. You can't submit an edit on non existant entry to create one.

$dbh is the database handle for the Inventory Database
$hashref is a hash of values, usually as a result of the user submitting a form, e.g. your %POST values. The hash must contain the following keys with values for a successful creation of a host to hostgroup mapping:

$hash{'membership_id'}
$hash{'hostgroup_id'}
$hash{'host_id'}

=head3 get_memberships_info($dbh,$optional_membershipid)
 
The information subroutine returns the information for all entries in the form of an array with each array entry being a hash of the values returned for that row.

Optionally a numerical unique id for the filed you are interested in can be supplied after the database handle. This will return only one specific result. Note that if you pass a (invalid) non numeric id the routine will default back to showing all entries, which might come as a bit of a shock the first time it happens. If you pass a id of the valid format but invalid to the database you'll get no results.

Note that this specific subroutine does not return the hashed error/success messages of style returned by the the other subroutines in this module. This routine will return data or return null.

=head3 count_memberships($dbh,'group' OR 'host')

This subroutine is actually a wrapper to the call for all get_memberships_info, geared towards providing useful summaries of memberships per group or groups per host, depending on the method used to call it.

If no database handle or arguemnt are given, the subroutine will exit with a hash error message as per the 'create' and 'edit' subroutines in this module.

If 'group' is specified, the total hosts per group will be returned with totals per status. This gives a group centric summary of the host to hostgroups mappings in a hash of hashes
.
e.g. using the oxmails group as an example, but remmebering all groups will be returned:
            $returned_hash{'oxmails'}{active}         = 3
            $returned_hash{'oxmails'}{inactive}       = 9
            $returned_hash{'oxmails'}{decommissioned} = 2
            $returned_hash{'oxmails'}{instock}        = 5
            $returned_hash{'oxmails'}{$hostgroup_id'} = 123;
        
If 'host' is specified, the total group memberships per host will be returned. Eg. a host centric summary of the host to hostgroups mappings.
The host centric summary isn't acutally used at the moment, so its not refined to any purpose. If you change it please document it here and discuss with other members of the group.
        
=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected by the overall Inventory module is required. Other configuration is at the application level via a configuration file loaded via Config::Tiny in the calling script, but this module itself is only passed the resulting database handle.

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Inventory;
Inventory::Hosts;
Inventory::Hostgroups;

=head1 BUGS AND LIMITATIONS
Probably tonnes.

As mentioned in the relevant section, the host centric calling method of count_memberships() is provided but not used at this time and so might need further development.

=head1 AUTHOR
Guy Edwards guyjohnedwards@gmail.com

=head1 COPYRIGHT & LICENSE

Copyright (c) The University of Oxford 2008. All Rights Reserved.
