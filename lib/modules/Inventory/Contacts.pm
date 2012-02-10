#!/usr/bin/perl -T
#
# Name: Contacts.pm
# Creator: Guy Edwards
# Created: 2012-01-30
# Description: Module for handling data about contacts
#
# $Id: Contacts.pm 3532 2012-02-09 09:38:20Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-09 09:38:20 +0000 (Thu, 09 Feb 2012) $
# $LastChangedRevision: 3532 $
#

package Inventory::Contacts;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_contacts
  get_contacts_info
  get_contacts_bysupplier
  edit_contacts
  delete_contacts
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;

sub create_contacts {

    # respond to a request to create a contact
    # 1. validate input
    # 2. make the database entry
    # 3. return success or fail
    #
    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'contact_name'}
        || $input->{'contact_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'contact_name'} < 1
        || length $input->{'contact_name'} > $MAX_NAME_LENGTH )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth = $dbh->prepare(
'INSERT INTO contacts(name,supplier_id,role,address,telephone,email,notes) VALUES(?,?,?,?,?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'contact_name'},
            $input->{'supplier_id'},
            $input->{'contact_role'},
            $input->{'contact_address'},
            $input->{'contact_telephone'},
            $input->{'contact_email'},
            $input->{'contact_notes'}

        )
      )
    {
        $message{'ERROR'} =
          "Internal Error: The contact creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The contact creation was successful';
    return \%message;
}

sub edit_contacts {

    # similar to creating a contact except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'contact_name'}
        || $input->{'contact_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'contact_name'} ) < 1
        || length( $input->{'contact_name'} ) > $MAX_NAME_LENGTH
        || !exists $input->{'contact_id'}
        || $input->{'contact_id'} !~ m/^[\d]+$/x )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth = $dbh->prepare(
'UPDATE contacts SET name=?,supplier_id=?,role=?,address=?,telephone=?,email=?,notes=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $input->{'contact_name'},
            $input->{'supplier_id'},
            $input->{'contact_role'},
            $input->{'contact_address'},
            $input->{'contact_telephone'},
            $input->{'contact_email'},
            $input->{'contact_notes'},

            $input->{'contact_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The contact entry edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your contact changes were commited successfully';
    return \%message;
}

sub delete_contacts {

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

    my $sth = $dbh->prepare('DELETE FROM contacts WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The contact entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
}

sub get_contacts_bysupplier {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           contacts.id,
           contacts.name,
           contacts.supplier_id,
           contacts.role,
           contacts.email,
           contacts.address,
           contacts.telephone,
           contacts.notes,
           suppliers.name AS supplier_name
        FROM contacts,suppliers
        WHERE
           contacts.supplier_id=suppliers.id AND
           contacts.supplier_id = ?
        ORDER BY
           contacts.name
        '
        );
        return if !$sth->execute($id);
    }
    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }

    return @return_array;
}

sub get_contacts_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           contacts.id,
           contacts.name,
           contacts.supplier_id,
           contacts.role,
           contacts.email,
           contacts.address,
           contacts.telephone,
           contacts.notes,
           suppliers.name AS supplier_name
        FROM contacts,suppliers
        WHERE
           contacts.supplier_id=suppliers.id AND
           contacts.id = ?
        ORDER BY
           contacts.name
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           contacts.id,
           contacts.name,
           contacts.supplier_id,
           contacts.role,
           contacts.email,
           contacts.address,
           contacts.telephone,
           contacts.notes,
           suppliers.name AS supplier_name
        FROM contacts,suppliers
        WHERE
           contacts.supplier_id=suppliers.id
        ORDER BY
           contacts.name
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

=head1 AUTHOR

Guy Edwards, maintained by <guyjohnedwards@gmail.com>

=head1 LICENSE AND COPYRIGHT

(c) Guy Edwards
