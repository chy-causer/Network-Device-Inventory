package Inventory::Frodos;
use strict;
use warnings;

=pod

=head1 NAME

  Inventory::Frodos

=head1 VERSION

This document describes Inventory::Frodos version 1.01

=head1 SYNOPSIS

  use Inventory::Frodos;

=head1 DESCRIPTION

Functions for dealing with the FroDo project specific data and analysis of it.

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  ordered_hash_frodos
  list_frodos
);

=pod

=head1 DEPENDENCIES

DBI
DBD::Pg

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

Readonly my %SORT_COLUMN => (
    host_name             => 'host_name',
    host_address          => 'host_address',
    host_lastresolvedfqdn => 'host_lastresolvedfqdn',
    model_name            => 'model_name',
    location_name         => 'location_name',
);
Readonly my $DEFAULT_COLUMN => 'host_name';

=pod

=head1 SUBROUTINES/METHODS

=head2 list_frodos

  list_frodos($dbh)

=cut

sub list_frodos {
    my $dbh = shift;

    return if !defined $dbh;

    my $sth =
      $dbh->prepare( 'SELECT'
          . ' hosts.name AS host_name,'
          . ' hosts.id AS host_id,'
          . ' interfaces.lastresolvedfqdn AS host_lastresolvedfqdn,'
          . ' interfaces.address AS host_address,'
          . ' interfaces.id AS interface_id,'
          . ' models.name AS model_name,'
          . ' locations.name AS location_name '
          . 'FROM hosts,interfaces,models,locations,status ' . 'WHERE'
          . ' interfaces.host_id = hosts.id'
          . " AND hosts.name ILIKE '%frodo%'"
          . ' AND hosts.model_id=models.id'
          . ' AND hosts.location_id=locations.id'
          . ' AND hosts.status_id = status.id'
          . " AND status.state='ACTIVE' "
          . 'ORDER BY host_lastresolvedfqdn;' );

    return if !$sth->execute();

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 ordered_hash_frodos

  ordered_hash_frodos( $dbh, $orderby )

=cut

sub ordered_hash_frodos {
    my ( $dbh, $orderby ) = @_;

    return if !defined $dbh;

    my $sth =
      $dbh->prepare( "SELECT"
          . ' hosts.name AS host_name,'
          . ' hosts.id AS host_id,'
          . ' interfaces.lastresolvedfqdn AS host_lastresolvedfqdn,'
          . ' interfaces.address AS host_address,'
          . ' interfaces.id AS interface_id,'
          . ' models.name AS model_name,'
          . ' locations.name AS location_name '
          . 'FROM hosts,interfaces,models,locations,status ' . 'WHERE'
          . ' interfaces.host_id = hosts.id'
          . " AND hosts.name ILIKE '%frodo%'"
          . ' AND hosts.model_id=models.id'
          . ' AND hosts.location_id=locations.id'
          . ' AND hosts.status_id = status.id'
          . " AND status.state='ACTIVE' "
          . 'ORDER BY host_lastresolvedfqdn;' );

    return if !$sth->execute();

    my $counter = 1;
    my %result_hash;
    my %return_hash;

    while ( my $reference = $sth->fetchrow_hashref ) {
        $result_hash{$counter} = $reference;
        $counter++;
    }

    %return_hash = %{ sort_frodo_results( $orderby, \%result_hash ) };

    return \%return_hash;
}

=pod

=head2 sort_frodo_results

  sort_frodo_results( $orderby, $unsorted )

If $orderby is not one of the expected values or is otherwise invalid it will
be reset to the default ordering.

Under review as to if this is still needed
https://github.com/guyed/Network-Device-Inventory/issues/48

=cut

sub sort_frodo_results {
    my ( $orderby, $unsorted ) = @_;
    my %semisorted_hash;
    my %sorted_hash;
    my $counter = 10;

    if ( $orderby =~ m/(\w+)/x ) {
        if ( !exists $SORT_COLUMN{$1} ) {
            $orderby = $DEFAULT_COLUMN;
        }
    }
    else {
        $orderby = $DEFAULT_COLUMN;
    }

    #first do a sort of the hash by the contained hash values
    while ( my ( $misc_key, $hash_ref ) = each( %{$unsorted} ) ) {

        # $misc_key is just a number we can ignore
        my %dbhash = %{$hash_ref};
        my $value  = $dbhash{$orderby};

        # we dont want to overwrite entries with the same sorting value
        # so we make it a compound
        if ( $orderby eq $DEFAULT_COLUMN ) {

            # sort numerically
            $value =~ s/\D//gx;
            $semisorted_hash{$value} = \%dbhash;
        }
        else {
            $semisorted_hash{"$value-$counter"} = \%dbhash;
        }
        $counter++;
    }

    $counter = 1;    # reuse it, why not
    if ( $orderby eq $DEFAULT_COLUMN ) {
        foreach my $key ( sort { $a <=> $b } keys %semisorted_hash ) {

            # generate a hash of hashes
            # with incremental numeric key
            $sorted_hash{$counter} = $semisorted_hash{$key};
            $counter++;
        }
    }
    else {
        foreach my $key ( sort keys %semisorted_hash ) {

            # generate a hash of hashes
            # with incremental numeric key
            $sorted_hash{$counter} = $semisorted_hash{$key};
            $counter++;

        }
    }

    return \%sorted_hash;
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
