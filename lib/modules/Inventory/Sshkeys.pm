package Inventory::Sshkeys;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_sshkeys
  delete_sshkeys
  edit_sshkeys
  get_sshkeys_info
  sshkeys_byhostid
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;

sub create_sshkeys {
    my $dbh   = shift;
    my %posts = %{ shift() };
    my %message;

    # chop off whitespace and the trailing dot you get on bash lines when the
    # sshkey unknown message is copy/pasted
    if ( exists $posts{'sshkey_fingerprint'} ) {
        $posts{'sshkey_fingerprint'} =~ s/\s//g;
        $posts{'sshkey_fingerprint'} =~ s/\.$//g;
    }

    if ( !exists $posts{'sshkey_fingerprint'}
        || $posts{'sshkey_fingerprint'} !~
        m/^([a-zA-Z0-9]{2}:)+([a-zA-Z0-9]{2})$/x
        || length( $posts{'sshkey_fingerprint'} ) < 1
        || length( $posts{'sshkey_fingerprint'} ) > 48 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = "Did you enter an invalid sshkey?";
        return \%message;
    }

    if (   !exists $posts{'host_id'}
        || $posts{'host_id'} =~ m/\D/x
        || length( $posts{'host_id'} ) < 1 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
"Programming error: invalid host_id in Inventory::Sshkeys::create_sshkeys";
        return \%message;
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
    my $sth =
      $dbh->prepare('INSERT INTO sshkeys(fingerprint,host_id) VALUES(?,?)');

    if ( !$sth->execute( $posts{'sshkey_fingerprint'}, $posts{'host_id'} ) ) {
        $message{'ERROR'} =
          "Internal Error: The SSH key creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} =
      "The SSH key creation $posts{'sshkey_fingerprint'} was successful";
    return \%message;
}

sub edit_sshkeys {
    my ( $dbh, $posts ) = @_;
    my %message;

    if ( !exists $posts->{'sshkey_fingerprint'}
        || $posts->{'sshkey_fingerprint'} !~
        m/^([a-zA-Z0-9]{2}:)+([a-zA-Z0-9]{2})$/x
        || length( $posts->{'sshkey_fingerprint'} ) < 1
        || length( $posts->{'sshkey_fingerprint'} ) > 48 )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} = "Did you enter an invalid sshkey?";
        return \%message;
    }

    my $sth =
      $dbh->prepare('UPDATE sshkeys SET host_id=?,fingerprint=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'sshkey_fingerprint'},
            $posts->{'sshkey_id'}
        )
      )
    {
        $message{'ERROR'} =
          "Internal Error: The interface edit was unsuccessful.";
        return \%message;
    }

    $message{'SUCCESS'} = "Your changes were commited successfully";
    return \%message;
}

sub sshkeys_byhostid {
    my ( $dbh, $host_id ) = @_;

    return if !$dbh;
    return if !$host_id;

    my $sth =
      $dbh->prepare('SELECT id,fingerprint FROM sshkeys WHERE host_id=?');

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

sub get_sshkeys_info {
    my ( $dbh, $sshkey_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $sshkey_id ) {
        $sth = $dbh->prepare(
            'SELECT 
            sshkeys.id,
            sshkeys.fingerprint,
            sshkeys.host_id,
            hosts.name AS host_name,
            hosts.id   AS host_id,
            hosts.status_id,
            status.state
         FROM 
            sshkeys,hosts,status
         WHERE
            sshkeys.host_id = hosts.id
            AND status.id = hosts.status_id
            AND sshkeys.id=?
         ORDER BY
            hosts.name
        '
        );
        return if !$sth->execute($sshkey_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
            sshkeys.id,
            sshkeys.fingerprint,
            sshkeys.host_id,
            hosts.name AS host_name,
            hosts.id   AS host_id,
            hosts.status_id,
            status.state
         FROM 
            sshkeys,hosts,status
         WHERE
            sshkeys.host_id = hosts.id
            AND status.id = hosts.status_id
         ORDER BY 
            hosts.name
        '
        );
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub delete_sshkeys {

    # delete a single contact

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM sshkeys WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The contact entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
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
