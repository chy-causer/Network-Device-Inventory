package Inventory::Cnames;
use strict;
use warnings;

=pod

=head1 NAME

  Inventory::Cnames

=head1 VERSION

This document describes Inventory::Cnames version 1.03

=head1 SYNOPSIS

  use Inventory::Cnames;

=head1 DESCRIPTION

Functions for dealing with the Cnames related data and analysis of it.

=cut

our $VERSION = '1.03';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_cnames
  create_shortcnames
  delete_cnames
  edit_cnames
  get_cnames_info
);

=pod

=head1 DEPENDENCIES

DBI;
DBD::Pg;
Readonly;

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

Readonly my $MAX_NAME_LENGTH    => '25';
Readonly my $MAX_DNSNAME_LENGTH => '128';

Readonly my $ENTRY          => 'cname';
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

Readonly my $MSG_SHORTNAME_ERR => 'The shortname was invalid';
Readonly my $MSG_DNSNAME_ERR   => 'The dnsname was invalid';

=pod

=head1 SUBROUTINES/METHODS

=head2 _internal_checkinput

An attempt at putting all input checking in one subroutine.

=cut

sub _internal_checkinput {
    my $posts = shift;
    my @message_store;

    if (   !exists $posts->{'shortname'}
        || $posts->{'shortname'} =~ m/[^\w\s\-]/x
        || length( $posts->{'shortname'} ) < 1
        || length( $posts->{'shortname'} ) > $MAX_NAME_LENGTH )
    {

        my %message;
        $message{'ERROR'} = $MSG_SHORTNAME_ERR;
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    if (   !exists $posts->{'dnsname'}
        || $posts->{'dnsname'} =~ m/[^\w\-]/x
        || length( $posts->{'dnsname'} ) < 1
        || length( $posts->{'dnsname'} ) > $MAX_DNSNAME_LENGTH )
    {

        my %message;
        $message{'ERROR'} = $MSG_DNSNAME_ERR;
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
    }

    return @message_store;
}

=pod

=head2 create_cnames

Main creation sub.
  create_cnames($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic cname name sanity.

Depends on the DNS records being provided (target/destination)

=cut

sub create_cnames {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my @message_store = _internal_checkinput($posts);

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
    }

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

=pod

=head2 create_shortcnames

In contrast to create_cnames this uses the hosts_id to generate a DNS record
from the stored shortname, it's otherwise identical

  create_shortcnames( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic cname name sanity.

=cut

sub create_shortcnames {
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

=pod

=head2 delete_cnames

Delete a single cname.

  delete_cnames( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_cnames {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM cnames WHERE id=?');
    if !$sth->execute($id){ return { 'ERROR' => $MSG_DELETE_ERR } }

          return { 'SUCCESS' => $MSG_DELETE_OK };
}

=pod

=head2 edit_cnames

Main edit sub.
  edit_cnames ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for missing database handle and id.

=cut

sub edit_cnames {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'cname_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    my @message_store = _internal_checkinput($posts);

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return @message_store;
        }
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

=pod

=head2 edit_shortcnames

Indentical to edit_cnames except using the host_id to automatically fill part
of the dns record.

Main edit sub.
  edit_shortcnames ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for missing database handle and host_id.

=cut

sub edit_shortcnames {
    my ( $dbh, $posts ) = @_;
    my $shortname;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

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

=pod

=head2 get_cnames_info

Main record retrieval sub, note that it retrieves by host_id.
 get_cnames_info ( $dbh, $host_id )

Returns the details in a hash.

=cut

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

=head1 DIAGNOSTICS

Via error messages where present.

=head1 INCOMPATIBILITIES

None known

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
