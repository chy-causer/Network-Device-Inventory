#!/usr/bin/perl -T
#
# Name: Frodos.pm
# Creator: Guy Edwards
# Created: 2008-11-07
# Description: subs for frodo detail recording
#
# $Id: Frodos.pm 3524 2012-02-06 15:52:19Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 15:52:19 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3524 $
# $uid: cqlfHNGDWfocQnQV0F1QNmIvD7VJM8iXClynMzsBqUJuM $
#
package Inventory::Frodos;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  ordered_hash_frodos
  list_frodos
);

use DBI;
use DBD::Pg;

sub list_frodos {
    my $dbh = shift;

    return if !defined $dbh;

    my $sth =
      $dbh->prepare( "SELECT"
          . " hosts.name AS host_name,"
          . " hosts.id AS host_id,"
          . " interfaces.lastresolvedfqdn AS host_lastresolvedfqdn,"
          . " interfaces.address AS host_address,"
          . " interfaces.id AS interface_id,"
          . " models.name AS model_name,"
          . " locations.name AS location_name "
          . "FROM hosts,interfaces,models,locations,status " . "WHERE"
          . " interfaces.host_id = hosts.id"
          . " AND hosts.name ILIKE '%frodo%'"
          . " AND hosts.model_id=models.id"
          . " AND hosts.location_id=locations.id"
          . " AND hosts.status_id = status.id"
          . " AND status.state='ACTIVE' "
          . "ORDER BY host_lastresolvedfqdn;" );

    return if !$sth->execute();

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub ordered_hash_frodos {
    my ( $dbh, $orderby ) = @_;

    return if !defined $dbh;

    my $sth =
      $dbh->prepare( "SELECT"
          . " hosts.name AS host_name,"
          . " hosts.id AS host_id,"
          . " interfaces.lastresolvedfqdn AS host_lastresolvedfqdn,"
          . " interfaces.address AS host_address,"
          . " interfaces.id AS interface_id,"
          . " models.name AS model_name,"
          . " locations.name AS location_name "
          . "FROM hosts,interfaces,models,locations,status " . "WHERE"
          . " interfaces.host_id = hosts.id"
          . " AND hosts.name ILIKE '%frodo%'"
          . " AND hosts.model_id=models.id"
          . " AND hosts.location_id=locations.id"
          . " AND hosts.status_id = status.id"
          . " AND status.state='ACTIVE' "
          . "ORDER BY host_lastresolvedfqdn;" );

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

sub sort_frodo_results {
    my ( $orderby, $unsorted ) = @_;
    my %semisorted_hash;
    my %sorted_hash;
    my $counter = 10000;

    $orderby =~ m/(\w+)/x;
    if ($1) {
        $orderby = $1;

        if (    $orderby ne 'host_name'
            and $orderby ne 'host_address'
            and $orderby ne 'host_lastresolvedfqdn'
            and $orderby ne 'model_name'
            and $orderby ne 'location_name' )
        {

            $orderby = 'host_name';
        }
    }
    else {
        $orderby = 'host_name';
    }

    #first do a sort of the hash by the contained hash values
    while ( my ( $misc_key, $hash_ref ) = each( %{$unsorted} ) ) {

        # $misc_key is just a number we can ignore
        my %dbhash = %{$hash_ref};
        my $value  = $dbhash{$orderby};

        # we dont want to overwrite entries with the same sorting value
        # so we make it a compound
        if ( $orderby eq 'host_name' ) {

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
    if ( $orderby eq 'host_name' ) {
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

=head1 NAME
Frodos.pm

=head1 VERSION

This documentation refers to  version 

=head1 USAGE

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 DESCRIPTION

=head1 DIAGNOSTICS

error messages

=head1 CONFIGURATION

Configuration files used?

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

none known

=head1 BUGS AND LIMITATIONS

Report any found to <guyjohnedwards@gmail.com>

=head1 AUTHOR

Guy Edwards, maintained by <guyjohnedwards@gmail.com>

=head1 LICENSE AND COPYRIGHT

(c) Guy Edwards
