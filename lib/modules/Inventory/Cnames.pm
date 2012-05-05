package Inventory::Cnames;
use strict;
use warnings;

=pod

=head1 NAME

  Inventory::Cnames

=head2 VERSION

This document describes Inventory::Cnames version 1.01

=head1 SYNOPSIS

  use Inventory::Cnames;

=head1 DESCRIPTION

Functions for dealing with the Cnames related data and analysis of it.

=cut

our $VERSION = '1.01';
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
use Inventory::Hosts 1.0;
my $MAX_NAME_LENGTH    = 25;
my $MAX_DNSNAME_LENGTH = 128;

my $ENTRY          = 'cname';
my $MSG_DBH_ERR    = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR  = 'Input Error: Please check your input';
my $MSG_CREATE_OK  = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK    = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR   = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK  = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR  = 'The error was fatal, processing stopped';

sub _internal_checkinput {
    my %posts = %{ shift() };
    my @message_store;    # need to put all these messages somewhere

    if (   !exists $posts{'shortname'}
        || $posts{'shortname'} =~ m/[^\w\s\-]/x
        || length( $posts{'shortname'} ) < 1
        || length( $posts{'shortname'} ) > $MAX_NAME_LENGTH )
    {

        my %message;
        $message{'ERROR'} =
"Internal Error: The application thinks it didn't get a shortname for the record, or that the shortname given had invalid syntax or length";
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    if (   !exists $posts{'dnsname'}
        || $posts{'dnsname'} =~ m/[^\w\-]/x
        || length( $posts{'dnsname'} ) < 1
        || length( $posts{'dnsname'} ) > $MAX_DNSNAME_LENGTH )
    {

        my %message;
        $message{'ERROR'} =
"Internal Error: The application thinks it didn't get a dnsname for the record, or that the dnsname given had invalid syntax or length";
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    if (   !exists $posts{'host_id'}
        || $posts{'host_id'} =~ m/\D/x
        || length( $posts{'host_id'} ) < 1 )
    {

        my %message;
        $message{'ERROR'} =
"Internal Error: The application thinks it didn't get a host_id for the record, or that the host_id given had invalid syntax or zero length";
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    return @message_store;

}

sub create_cnames {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    # validate input
    my @message_store = _internal_checkinput($posts);

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
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

sub create_shortcname {
    my ( $dbh, $posts ) = @_;
    my %message;
    my @message_store;
    my $shortname;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my $sth = $dbh->prepare('SELECT name FROM hosts WHERE id=?');
    if ( !$sth->execute( $posts->{host_id} ) ) {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    while ( my $reference = $sth->fetchrow_hashref ) {
        $shortname = $reference->{name};
    }

    my $sth2 = $dbh->prepare(
        'INSERT INTO cnames(host_id,shortname,dnsname) VALUES(?,?,?)');
    if ( !$sth2->execute( $posts->{'host_id'}, $shortname, $posts->{'dnsname'} )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

sub delete_cname {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM cnames WHERE id=?');
    if !$sth->execute($id){ return { 'ERROR' => $MSG_DELETE_ERR } }

          return { 'SUCCESS' => $MSG_DELETE_OK };
}

sub edit_cnames {
    my ( $dbh, $posts ) = @_;
    my %message;

    my @message_store = _internal_checkinput($posts);

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

    if (   !exists $posts->{'cname_id'}
        || $posts->{'cname_id'} =~ m/\D/x
        || length( $posts->{'cname_id'} ) < 1 )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
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
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

sub edit_shortcnames {
    my ( $dbh, $posts ) = @_;
    my $shortname;

    my $sth = $dbh->prepare('SELECT name FROM hosts WHERE id=?');
    if ( !$sth->execute( $posts->{host_id} ) ) {
        return { 'ERROR' => $MSG_EDIT_ERR };
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
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
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

=pod

=head2 Main Subroutines

=head3 create_cnames($dbh,$hashref)

$dbh is the database handle for the Inventory Database

This subrouting will always return a hashref with the SUCCESS or ERROR state
recorded in the hash key and the human description recorded in the hash keys
value, e.g.  $message{'SUCCESS'} = 'Your changes were commited successfully';

=head3 edit_cnames($dbh,$hashref)
=head3 list_cnames_info($dbh,$optional_manufacturersid)

=head1 CONFIGURATION AND ENVIRONMENT

A postgres database with the database layout that's expected by the overall
Inventory module is required. Other configuration is at the application level
via a configuration file loaded via Config::Tiny in the calling script, but
this module itself is only passed the resulting database handle.

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

The University of Oxford agrees to the release under the GPL of in the program
`Inventory' written by Guy Edwards as agreed by Dr. Stuart Lee, Director of
Oxford University Computer Services.

Oliver Gorwits, who in 2008 contributed sections of the hostgroups programming
also agreed to the code release under the GPL.
