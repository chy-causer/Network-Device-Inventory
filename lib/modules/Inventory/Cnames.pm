package Inventory::Cnames;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_cnames
  create_shortcname
  delete_cname
  edit_cnames
  get_cnames_info
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;
use Inventory::Hosts qw(get_hosts_info);

sub internal_checkinput {
    my %posts = %{ shift() };
    my @message_store;    # need to put all these messages somewhere

    if (   !exists $posts{'shortname'}
        || $posts{'shortname'} =~ m/[^\w\s\-]/x
        || length( $posts{'shortname'} ) < 1
        || length( $posts{'shortname'} ) > 25 )
    {

        my %message;
        $message{'ERROR'} =
"Internal Error: The application thinks it didn't get a shortname for the record, or that the shortname given had invalid syntax or length";
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
    }

    if (   !exists $posts{'dnsname'}
        || $posts{'dnsname'} =~ m/[^\w\-]/x
        || length( $posts{'dnsname'} ) < 1
        || length( $posts{'dnsname'} ) > 80 )
    {

        my %message;
        $message{'ERROR'} =
"Internal Error: The application thinks it didn't get a dnsname for the record, or that the dnsname given had invalid syntax or length";
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
    }

    if (   !exists $posts{'host_id'}
        || $posts{'host_id'} =~ m/\D/x
        || length( $posts{'host_id'} ) < 1 )
    {

        my %message;
        $message{'ERROR'} =
"Internal Error: The application thinks it didn't get a host_id for the record, or that the host_id given had invalid syntax or zero length";
        $message{'FATAL'} = "The error was fatal";
        push @message_store, \%message;
    }

    return @message_store;

}

sub create_cnames {
    my ( $dbh, $posts ) = @_;
    my %message;

    # validate input
    my @message_store = internal_checkinput($posts);

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
    my $sth = $dbh->prepare(
        'INSERT INTO cnames(host_id,shortname,dnsname) VALUES(?,?,?)');

    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'shortname'}, $posts->{'dnsname'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The cname creation was unsuccessful';
        push @message_store, \%message;
        return @message_store;
    }

    $message{'SUCCESS'} =
"The cname creation ($posts->{'dnsname'} to $posts->{'shortname'}) was successful";
    push @message_store, \%message;

    return @message_store;
}

sub create_shortcname {
    my ( $dbh, $posts ) = @_;
    my %message;
    my @message_store;
    my $shortname;

    my $sth = $dbh->prepare('SELECT name FROM hosts WHERE id=?');
    if ( !$sth->execute( $posts->{host_id} ) ) {
        $message{'ERROR'} =
          'Internal Error: The cname creation was unsuccessful';
        push @message_store, \%message;
        return @message_store;
    }

    while ( my $reference = $sth->fetchrow_hashref ) {
        $shortname = $reference->{name};
    }

    my $sth2 = $dbh->prepare(
        'INSERT INTO cnames(host_id,shortname,dnsname) VALUES(?,?,?)');
    if ( !$sth2->execute( $posts->{'host_id'}, $shortname, $posts->{'dnsname'} )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The cname creation was unsuccessful';
        push @message_store, \%message;
        return @message_store;
    }

    $message{'SUCCESS'} =
"The cname creation ($posts->{'dnsname'} to $posts->{'shortname'}) was successful";
    push @message_store, \%message;

    return @message_store;
}

sub delete_cname {
    my ( $dbh, $cname_id ) = @_;

    return { 'ERROR' => 'Programming error' } if !defined $dbh;
    return { 'ERROR' => 'Programming error, no cname_id' }
      if !defined $cname_id;
    return { 'ERROR' => "Programming error, $cname_id contains non digits" }
      if $cname_id =~ m/\D/x;
    return { 'ERROR' => 'Programming error, empty cname_id' }
      if length($cname_id) < 1;

    my $sth = $dbh->prepare('DELETE FROM cnames WHERE id=?');
    return {
        'ERROR' => 'Programming error, database refused to delete the record' }
      if !$sth->execute($cname_id);

    # congratulations, you made it
    return { 'SUCCESS' => 'Host alias deleted' };
}

sub edit_cnames {
    my ( $dbh, $posts ) = @_;

    my %message;

    # validate input
    my @message_store = internal_checkinput($posts);

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

    # dump bad inputs
    if (   !exists $posts->{'cname_id'}
        || $posts->{'cname_id'} =~ m/\D/x
        || length( $posts->{'cname_id'} ) < 1 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: One of the supplied inputs was invalid.';
        push @message_store, \%message;
        return @message_store;
    }

    my $sth = $dbh->prepare(
        'UPDATE cnames SET host_id=?,shortname=?,dnsname=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'shortname'},
            $posts->{'dnsname'}, $posts->{'cname_id'}
        )
      )
    {
        $message{'ERROR'} = 'Internal Error: The cname edit was unsuccessful.';

        push @message_store, \%message;
        return @message_store;
    }

    $message{'SUCCESS'} = 'Your host name changes were commited successfully';
    push @message_store, \%message;
    return @message_store;
}

sub edit_shortcnames {
    my ( $dbh, $posts ) = @_;

    my %message;
    my @message_store;
    my $shortname;

    my $sth = $dbh->prepare('SELECT name FROM hosts WHERE id=?');
    if ( !$sth->execute( $posts->{host_id} ) ) {
        $message{'ERROR'} = 'Internal Error: The cname edit was unsuccessful';
        push @message_store, \%message;
        return @message_store;
    }

    while ( my $reference = $sth->fetchrow_hashref ) {
        $shortname = $reference->{name};
    }

    my $sth1 = $dbh->prepare(
        'UPDATE cnames SET host_id=?,shortname=?,dnsname=? WHERE id=?');
    if (
        !$sth1->execute(
            $posts->{'host_id'}, $shortname,
            $posts->{'dnsname'}, $posts->{'cname_id'}
        )
      )
    {
        $message{'ERROR'} = 'Internal Error: The cname edit was unsuccessful.';

        push @message_store, \%message;
        return @message_store;
    }

    $message{'SUCCESS'} = 'Your host name changes were commited successfully';
    push @message_store, \%message;
    return @message_store;
}

sub get_cnames_info {
    my ( $dbh, $host_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $host_id ) {
        $sth = $dbh->prepare(
'SELECT id,host_id,shortname,dnsname FROM cnames WHERE host_id=? ORDER BY dnsname'
        );
        return if !$sth->execute($host_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT id,host_id,shortname,dnsname FROM cnames ORDER BY dnsname');
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

1;
__END__

=head1 NAME

Inventory::Cnames - Information on Cnames

=head2 VERSION

This document describes Inventory::Cnames version 0.0.1

=head1 SYNOPSIS

  use Inventory::Cnames qw(create_cnames edit_cnames show_cnames_info);
  # There are no special setup requirements

=head1 PURPOSE

This module allows manipulation of the inventory database cnames table

=head1 DESCRIPTION


The module aims to hide the tasks of raw SQL queries to the database from wou
when performing common tasks which involve the relationhips of manufacturers
to models in the inventory table.

At a very late stage the inventory database had the requirement added that the
dns zone for the frodos and frodo ups's would be created from the inventory.
This was a problem since the inventory relies on the dns...  This set of
subroutines hence deals with the slightly clunky solution which was a database
table linking the host to it's dns and cnames that would be used to populate
the dns

The data returned from a query should be generous, as well as the ids of the
hosts involved the names, statuses and similar are returned. Each subroutine
should also give a descriptive success or failure message.

=head2 Main Subroutines

=head3 create_cnames($dbh,$hashref)

$dbh is the database handle for the Inventory Database

This subrouting will always return a hashref with the SUCCESS or ERROR state recorded in the hash key and the human description recorded in the hash keys value, e.g.
$message{'SUCCESS'} = 'Your changes were commited successfully';

=head3 edit_cnames($dbh,$hashref)
=head3 list_cnames_info($dbh,$optional_manufacturersid)

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected by the overall Inventory module is required. Other configuration is at the application level via a configuration file loaded via Config::Tiny in the calling script, but this module itself is only passed the resulting database handle.

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Inventory;
Inventory::Hosts;

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

The University of Oxford disclaims all copyright interest in the program
`Inventory' written by Guy Edwards as agreed by Dr. Stuart Lee, Director of
Oxford University Computer Services.

Oliver Gorwits, who in 2008 contributed sections of the hostgroups programming
also disclaims all copyright interest in the program.
