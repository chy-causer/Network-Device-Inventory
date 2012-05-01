package Inventory::Servicelevels;
use strict;
use warnings;

our $VERSION = '1.00';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_servicelevels
  get_servicelevels_info
  edit_servicelevels
  delete_servicelevels
);

use DBI;
use DBD::Pg;

my $MAX_NAME_LENGTH = 128;

sub create_servicelevels {

    # respond to a request to create a servicelevel
    # 1. validate input
    # 2. make the database entry
    # 3. return success or fail
    #
    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'servicelevel_name'}
        || $input->{'servicelevel_name'} !~ m/^[\w\s\-]+$/x
        || length $input->{'servicelevel_name'} < 1
        || length $input->{'servicelevel_name'} > $MAX_NAME_LENGTH )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth = $dbh->prepare(
        'INSERT INTO servicelevels(name,description,supplier_id) VALUES(?,?,?)'
    );

    if (
        !$sth->execute(
            $input->{'servicelevel_name'},
            $input->{'servicelevel_description'},
            $input->{'supplier_id'}

        )
      )
    {
        $message{'ERROR'} =
          "Internal Error: The servicelevel creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = 'The servicelevel creation was successful';
    return \%message;
}

sub edit_servicelevels {

    # similar to creating a servicelevel except we already (should) have a vaild
    # database id for the entry

    my ( $dbh, $input ) = @_;
    my %message;

    if (   !exists $input->{'servicelevel_name'}
        || $input->{'servicelevel_name'} !~ m/^[\w\s\-]+$/x
        || length( $input->{'servicelevel_name'} ) < 1
        || length( $input->{'servicelevel_name'} ) > $MAX_NAME_LENGTH )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          'Input Error: Please check your input is alpha numeric and complete';
        return \%message;
    }

    my $sth = $dbh->prepare(
        'UPDATE servicelevels SET name=?,description=?,supplier_id=? WHERE id=?'
    );
    if (
        !$sth->execute(
            $input->{'servicelevel_name'},
            $input->{'servicelevel_description'},
            $input->{'supplier_id'},

            $input->{'servicelevel_id'}
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The servicelevel entry edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} =
      'Your servicelevel changes were commited successfully';
    return \%message;
}

sub delete_servicelevels {

    # delete a single servicelevel

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM servicelevels WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The servicelevel entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
}

sub get_servicelevels_info {
    my ( $dbh, $id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $id ) {
        $sth = $dbh->prepare(
            'SELECT 
           servicelevels.id,
           servicelevels.name,
           servicelevels.description,
           suppliers.id AS supplier_id,
           suppliers.name AS supplier_name

        FROM servicelevels,suppliers
        
        WHERE 
           suppliers.id = servicelevels.supplier_id,
           servicelevels.id = ?
        
        ORDER BY 
           servicelevels.name
        '
        );
        return if !$sth->execute($id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           servicelevels.id,
           servicelevels.name,
           servicelevels.description,
           suppliers.id AS supplier_id,
           suppliers.name AS supplier_name

        FROM servicelevels,suppliers

        WHERE 
           suppliers.id = servicelevels.supplier_id
        
        ORDER BY 
           servicelevels.name
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

1;

__END__

=head1 NAME

Inventory::Servicelevels - Manipulate Servicelevels

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
