#!/usr/bin/perl -T
#
# Name: Suppliers.pm
# Creator: Guy Edwards
# Created: 2012-01-30
# Description: Module for handling data about suppliers
#
# $Id: Suppliers.pm 3533 2012-02-09 09:55:25Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-09 09:55:25 +0000 (Thu, 09 Feb 2012) $
# $LastChangedRevision: 3533 $
#

package Inventory::Suppliers;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_suppliers
  get_suppliers_info
  edit_suppliers
  delete_suppliers
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;

sub create_suppliers {

    # respond to a request to create a supplier
    # 1. validate input
    # 2. make the database entry
    # 3. return success or fail
    #
    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'supplier_name'}
        || $input->{'supplier_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'supplier_name'} < 1
        || length $input->{'supplier_name'} > $MAX_NAME_LENGTH )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth = $dbh->prepare(
'INSERT INTO suppliers(name,website,techphone,salesphone,address) VALUES(?,?,?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'supplier_name'},      $input->{'supplier_website'},
            $input->{'supplier_techphone'}, $input->{'supplier_salesphone'},
            $input->{'supplier_address'}
        )
      )
    {
        $message{'ERROR'} =
          "Internal Error: The supplier creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The supplier creation was successful';
    return \%message;
}

sub edit_suppliers {

    # similar to creating a supplier except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;

    if (

        !exists $input->{'supplier_name'}
        || $input->{'supplier_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'supplier_name'} ) < 1
        || length( $input->{'supplier_name'} ) > $MAX_NAME_LENGTH

        || !exists $input->{'supplier_id'}
        || $input->{'supplier_id'} !~ m/^[\d]+$/x

      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth = $dbh->prepare(
'UPDATE suppliers SET name=?,website=?,techphone=?,salesphone=?,address=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $input->{'supplier_name'},
            $input->{'supplier_website'},
            $input->{'supplier_techphone'},
            $input->{'supplier_salesphone'},
            $input->{'supplier_address'},

            $input->{'supplier_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The supplier entry edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your supplier changes were commited successfully';
    return \%message;
}

sub delete_suppliers {

    # delete a single supplier

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM suppliers WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The supplier entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
}

sub get_suppliers_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           suppliers.id,
           suppliers.name,
           suppliers.website,
           suppliers.techphone,
           suppliers.salesphone,
           suppliers.address
        FROM suppliers 
        WHERE
           suppliers.id = ?
        ORDER BY 
           suppliers.name
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           suppliers.id,
           suppliers.name,
           suppliers.website,
           suppliers.techphone,
           suppliers.salesphone,
           suppliers.address
        FROM suppliers 
        ORDER BY 
           suppliers.name
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