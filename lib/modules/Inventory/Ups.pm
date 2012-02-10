# $Id: Ups.pm 3535 2012-02-10 12:47:01Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-10 12:47:01 +0000 (Fri, 10 Feb 2012) $
# $LastChangedRevision: 3535 $
package Inventory::Ups;
use strict;
use warnings;

use version; our $VERSION = qv('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_ups
  delete_ups
  edit_ups
  get_ups_info
  get_links_info
  ups_byhostid
  host_byupsid
);

use DBI;
use DBD::Pg;
use Inventory::Hosts;
use Inventory::Introles;

sub create_ups {
    my ( $dbh, $posts ) = @_;

    # create a new entry of a host to a hostgroup
    my %message;

    # catch calling errors
    if ( !$dbh ) {
        $message{'ERROR'} =
'Internal Error: The database died or otherwise vanished before I could add the entry';
        return \%message;
    }

    # dont wave bad inputs at the database
    if (
           !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1

        || !exists $posts->{'ups_id'}
        || $posts->{'ups_id'} =~ m/\D/x
        || length( $posts->{'ups_id'} ) < 1
      )
    {
        $message{'ERROR'} =
          'Input Error: One of the supplied ids was non numeric';
        return \%message;
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
    my $sth = $dbh->prepare(
        'INSERT INTO hosts_to_upshost (host_id,ups_id) VALUES(?,?)');

    if ( !$sth->execute( $posts->{'host_id'}, $posts->{'ups_id'} ) ) {

        # find out what the error was
        my $full_error_string = $dbh->errstr;
        my $duplicate_entry_message =
          'duplicate key violates unique constraint';
        if ( $full_error_string =~ m/$duplicate_entry_message/ix ) {
            $message{'ERROR'} =
'Internal Error: You just tried to add a host to a ups that it is already a linked with.';
        }
        else {
            $message{'ERROR'} =
              'Internal Error: The host - ups link creation was unsuccessful.';
        }
        return \%message;
    }

    $message{'SUCCESS'} = 'The host - ups link creation was successful';
    return \%message;
}

sub delete_ups {
    my ( $dbh, $link_id ) = @_;

    return { 'ERROR' => 'Programming error' }             if !defined $dbh;
    return { 'ERROR' => 'Programming error, no link_id' } if !defined $link_id;
    return { 'ERROR' => "Programming error, $link_id contains non digits" }
      if $link_id =~ m/\D/x;
    return { 'ERROR' => 'Programming error, empty link_id' }
      if length($link_id) < 1;

    my $sth = $dbh->prepare('DELETE FROM hosts_to_upshost WHERE id=?');
    return {
        'ERROR' => 'Programming error, database refused to delete the record' }
      if !$sth->execute($link_id);

    # congratulations, you made it
    return { 'SUCCESS' => 'UPS link deleted' };
}

sub edit_ups {
    my ( $dbh, $posts ) = @_;
    my %message;

    # catch calling errors
    if ( !$dbh ) {
        $message{'ERROR'} =
'Internal Error: The database died or otherwise vanished before I could edit the entry';
        return \%message;
    }

    # dump bad inputs
    if (
           !exists $posts->{'link_id'}
        || $posts->{'link_id'} =~ m/\D/x
        || length $posts->{'link_id'} < 1

        || !exists $posts->{'ups_id'}
        || $posts->{'ups_id'} =~ m/\D/x
        || length $posts->{'ups_id'} < 1

        || !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length $posts->{'host_id'} < 1

      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: One of the supplied ids was non numeric';
        return \%message;
    }

    my $sth = $dbh->prepare(
        'UPDATE hosts_to_upshost SET host_id=?,ups_id=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'ups_id'}, $posts->{'link_id'}
        )
      )
    {

        # find out what the error was
        my $full_error_string = $dbh->errstr;
        my $duplicate_entry_message =
          'duplicate key violates unique constraint';
        if ( $full_error_string =~ m/$duplicate_entry_message/ix ) {
            $message{'ERROR'} =
'Input Error: You just tried to link a host to a ups that it is already linked with.';
        }
        else {
            $message{'ERROR'} =
              'Internal Error: The host to ups link edit was unsuccessful';
        }
        return \%message;
    }

    $message{'SUCCESS'} = 'Your UPS changes were commited successfully';
    return \%message;
}

sub ups_byhostid {
    my ( $dbh, $host_id ) = @_;

    return if !$dbh;
    return if !$host_id;

    my $sth =
      $dbh->prepare( "SELECT"
          . " hosts_to_upshost.id as link_id,"
          . " hosts_to_upshost.ups_id,"
          . " hosts.name AS ups_name "
          . "FROM hosts_to_upshost,hosts "
          . "WHERE hosts_to_upshost.host_id=? "
          . "AND hosts.id=hosts_to_upshost.ups_id" );

    # FIXME: we return error here but is it a useful way or returning? Can it
    # be improved?
    return 'ERROR' if !$sth->execute($host_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %result = %{$reference};
        push @return_array, \%result;
    }
    return @return_array;
}

sub host_byupsid {
    my ( $dbh, $host_id ) = @_;

    return if !$dbh;
    return if !$host_id;

    my $sth =
      $dbh->prepare('SELECT host_id FROM hosts_to_upshost WHERE ups_id=?');

    # FIXME: we return error here but is it a useful way or returning? Can it
    # be improved?
    return 'ERROR' if !$sth->execute($host_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        my %result = %{$reference};
        push @return_array, $result{'host_id'};
    }
    return @return_array;
}

sub get_links_info {
    my $dbh           = shift;
    my $membership_id = shift;
    my $sth;

    return if !$dbh;

    if ( defined $membership_id && $membership_id !~ m/\D/x ) {
        $sth = $dbh->prepare( '
            SELECT 
              hosts_to_upshost.id AS link_id,
              hosts_to_upshost.host_id AS host_id,
              hosts1.name AS host_name,
              hosts2.name AS ups_name,
              hosts_to_upshost.ups_id AS ups_id,
              interfaces2.id AS ups_interface_id,
              interfaces2.lastresolvedfqdn AS ups_lastresolvedfqdn,
              interfaces2.address AS ups_address
            FROM 
              hosts_to_upshost,
              hosts AS hosts1,
              hosts AS hosts2,
              interfaces AS interfaces2
            WHERE 
              hosts_to_upshost.id=?
              AND interfaces2.host_id = hosts_to_upshost.ups_id
              AND hosts_to_upshost.host_id=hosts1.id
              AND hosts_to_upshost.ups_id=hosts2.id
            ' );

        return if !$sth->execute($membership_id);
    }
    else {
        $sth = $dbh->prepare( '
            SELECT 
              hosts_to_upshost.id AS link_id,
              hosts_to_upshost.host_id AS host_id, 
              hosts1.name AS host_name,
              hosts2.name AS ups_name,
              hosts_to_upshost.ups_id AS ups_id,
              interfaces2.id AS ups_interface_id,
              interfaces2.lastresolvedfqdn AS ups_lastresolvedfqdn,
              interfaces2.address AS ups_address
            FROM 
              hosts_to_upshost,
              hosts AS hosts1,
              hosts AS hosts2,
              interfaces AS interfaces2
            WHERE
              interfaces2.host_id = hosts_to_upshost.ups_id
              AND hosts_to_upshost.host_id=hosts1.id
              AND hosts_to_upshost.ups_id=hosts2.id
            ' );
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

sub get_ups_info {
    my $dbh = shift;

    # return all hosts in the frodo_ups and ups groups
    # this means we can make a dropdown of hosts that are just ups's
    #
    my $sth = $dbh->prepare( "
        SELECT 
          hosts.id AS ups_id,
          hosts.name AS ups_name,
          hosts.description AS ups_description
        FROM hosts
            LEFT JOIN interfaces on hosts.id = interfaces.host_id
            LEFT JOIN interfaces_to_introles ON interfaces_to_introles.interface_id = interfaces.id
            LEFT JOIN introles ON interfaces_to_introles.introle_id = introles.id
        WHERE introles.name in ('device-ups-mge', 'device-sec-ups-mge')
        ORDER BY ups_name ASC
    " );

    # FIXME - the category names should be in a config file not hardcoded vars
    return if !$sth->execute;

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub count_ups {
    my ( $dbh, $request ) = @_;
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
'Internal Error: The database vanished before a listing of its contents could be counted';
        return \%message;
    }
    if ( !defined $request ) {
        $message{'ERROR'} =
'Internal Error: There is a programming error in a call to Inventory::Ups::count_ups';
        return \%message;
    }

    my $sth;
    my @raw_data = Inventory::Ups::get_ups_info($dbh);

    my %return_hash;
    if ( $request eq 'ups' ) {

        # cycle through the raw data
        # by group total up states
        foreach (@raw_data) {
            my %dbdata    = %{$_};
            my $ups_name  = $dbdata{'ups_name'};
            my $ups_state = lc $dbdata{'ups_state'};
            my $ups_id    = $dbdata{'ups_id'};

            $return_hash{$ups_name}{$ups_state}++;
            $return_hash{$ups_name}{'ups_id'} = $ups_id;
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

If you wish to investigate what groups a host is in: or conversly to discover
what hosts are in a hostgroup, then this module assists in that process. A
subroutine is procided for each of: creating, editing, listing all entries,
and listing summary totals of the relationships.

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
$message{'SUCCESS'} = 'Your UPS changes were commited successfully';


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

Copyright (c) Guy Edwards
