package Inventory::Hosts;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Hosts

=head1 VERSION

This document describes Inventory::Hosts version 1.02

=head1 SYNOPSIS

  use Inventory::Hosts;

=head1 DESCRIPTION

Functions for dealing with the Hosts table related data

=cut

our $VERSION = '1.03';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hosts
  edit_hosts
  delete_hosts
  get_hosts_info
  get_hosts_info_by_name
  host_info_wrapper
  update_time
);

=pod

=head1 DEPENDENCIES

DBI
DBD::Pg
Net::DNS
Readonly

=cut

use DBI;
use DBD::Pg;
use Net::DNS;
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

Readonly my $MAX_NAME_LENGTH => '45';
Readonly my $ENTRY           => 'host';

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

=pod

=head1 SUBROUTINES/METHODS

=head2 create_hosts

Main creation sub.
create_hosts($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic description sanity.

=cut

sub create_hosts {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (
           !exists $posts->{'host_name'}
        || $posts->{'host_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'host_name'} ) < 1
        || length( $posts->{'host_name'} ) > $MAX_NAME_LENGTH

        || !exists $posts->{'location_id'}
        || $posts->{'location_id'} =~ m/\D/x
        || length( $posts->{'location_id'} ) < 1

        || !exists $posts->{'status_id'}
        || $posts->{'status_id'} =~ m/\D/x
        || length( $posts->{'status_id'} ) < 1

        || !exists $posts->{'model_id'}
        || $posts->{'model_id'} =~ m/\D/x
        || length( $posts->{'model_id'} ) < 1
      )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    if ( exists $posts->{'host_description'}
        and defined $posts->{'host_description'} )
    {
        $posts->{'host_description'} =~ s/[^\w\s\-]//gx;
    }
    $posts->{'host_name'} = lc $posts->{'host_name'};

    if (   not exists $posts->{'invoice_id'}
        or not defined $posts->{'invoice_id'}
        or length $posts->{'invoice_id'} < 1 )
    {
        $posts->{'invoice_id'} = undef;
    }

    my $sth = $dbh->prepare(
        'INSERT INTO hosts(
        name,
        location_id,
        status_id,
        model_id,
        description,
        asset,
        serial,
        invoice_id
        ) VALUES(?,?,?,?,?,?,?,?)
    '
    );

    if (
        !$sth->execute(
            $posts->{'host_name'},        $posts->{'location_id'},
            $posts->{'status_id'},        $posts->{'model_id'},
            $posts->{'host_description'}, $posts->{'host_asset'},
            $posts->{'host_serial'},      $posts->{'invoice_id'},
        )
      )
    {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_hosts

Main edit sub.
  edit_hosts ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for a missing database handle and basic description sanity.

=cut

sub edit_hosts {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }
    if ( !exists $posts->{'location_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }
    if ( !exists $posts->{'status_id'} ) {
        return { 'ERROR' => $MSG_PROG_ERR };
    }
    if ( !exists $posts->{'model_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    if (   !exists $posts->{'host_name'}
        || $posts->{'host_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'host_name'} ) < 1
        || length( $posts->{'host_name'} ) > $MAX_NAME_LENGTH )
    {

        # dont wave bad inputs at the database
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    if (   not exists $posts->{'invoice_id'}
        or not defined $posts->{'invoice_id'}
        or length $posts->{'invoice_id'} < 1 )
    {
        $posts->{'invoice_id'} = undef;
    }

    if ( exists $posts->{'host_description'}
        and defined $posts->{'host_description'} )
    {
        $posts->{'host_description'} =~ s/[^\w\s\-]//gx;
    }
    $posts->{'host_name'} = lc $posts->{'host_name'};

    my $sth = $dbh->prepare(
        'UPDATE hosts SET 
        name=?,
        location_id=?,
        status_id=?,
        model_id=?,
        description=?,
        asset=?,
        serial=?,
        invoice_id=?
        WHERE id=?
        '
    );
    if (
        !$sth->execute(
            $posts->{'host_name'},        $posts->{'location_id'},
            $posts->{'status_id'},        $posts->{'model_id'},
            $posts->{'host_description'}, $posts->{'host_asset'},
            $posts->{'host_serial'},      $posts->{'invoice_id'},
            $posts->{'host_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 host_info_wrapper

Helps retrieve all the hosts information 
 host_info_wrapper ( $dbh, $fieldname, $value )

Returns the details in a hash, the structure is host_id => @hostdetails

In the event of the database returning an error, the user gets a generic
program failure message, you'll need to check the webservers for details of
what the issue was.

=cut

sub host_info_wrapper {
    my ( $dbh, $fieldname, $value ) = @_;
    my %results;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if ( $fieldname eq 'asset' ) {
        my $sth = $dbh->prepare('SELECT id FROM hosts WHERE asset=?');

        if ( !$sth->execute($value) ) {

            # I'm not showing the user the exact error
            $results{'ERROR'} = $MSG_PROG_ERR;
            return \%results;
        }

        while ( my $reference = $sth->fetchrow_hashref ) {
            my %data = %{$reference};

            # an array with a single hashref in it
            my @info = Inventory::Hosts::get_hosts_info( $dbh, $data{'id'} );
            $results{ $data{'id'} } = \%{ $info[0] };
        }
        return \%results;
    }

    if ( $fieldname eq 'shortname' ) {
        my $like = "%$value%";
    
        my $sth = $dbh->prepare('SELECT id FROM hosts WHERE name ILIKE ?');

        if ( !$sth->execute($like) ) {
            $results{'ERROR'} = $MSG_PROG_ERR;
            return \%results;
        }

        while ( my $data = $sth->fetchrow_hashref ) {
            # an array with a single hashref in it
            my @info = Inventory::Hosts::get_hosts_info( $dbh, $data->{'id'} );
            $results{ $data->{'id'} } = \%{ $info[0] };
        }
        return \%results;
    }

    if ( $fieldname eq 'serial' ) {
        my $sth = $dbh->prepare('SELECT id FROM hosts WHERE serial=?');

        if ( !$sth->execute($value) ) {
            $results{'ERROR'} = $MSG_PROG_ERR;
            return \%results;
        }

        while ( my $reference = $sth->fetchrow_hashref ) {
            my %data = %{$reference};

            # an array with a single hashref in it
            my @info = Inventory::Hosts::get_hosts_info( $dbh, $data{'id'} );
            $results{ $data{'id'} } = \%{ $info[0] };
        }
        return \%results;
    }

    if ( $fieldname eq 'dnsname' ) {

        # if it's a dns name we can resolve it and use the ipaddress lookup
        # as the search
        my $res   = Net::DNS::Resolver->new;
        my $query = $res->query($value);

        my @ip_addresses;
        if ($query) {
            foreach my $rr ( $query->answer ) {
                next if not $rr->type eq 'A';
                push @ip_addresses, $rr->address;
            }
        }

        if ( !@ip_addresses || scalar @ip_addresses < 1 ) {

            # if it doesn't resolve we can look it up in the cached records
            # e.g. the dns entry is no longer live but we might have a record
            # of it cached
            my $sth = $dbh->prepare(
                'SELECT host_id FROM interfaces WHERE lastresolvedfqdn=?');

            if ( !$sth->execute($value) ) {
                $results{'ERROR'} = $MSG_PROG_ERR;
                return \%results;
            }

            while ( my $reference = $sth->fetchrow_hashref ) {
                my %data = %{$reference};
                my @info =
                  Inventory::Hosts::get_hosts_info( $dbh, $data{'id'} );
                $results{ $data{'id'} } = \%{ $info[0] };
            }
            return \%results;
        }

        # otherwise reset the values and fall through to the next routine
        $fieldname = 'ipaddress';
        $value     = "@ip_addresses";

    }

    if ( $fieldname eq 'ipaddress' ) {
        my @addresses = split /\s/, $value;
        my $counter = 0;    # for individual error messages
        foreach my $address (@addresses) {

            # we've got the address, lets find out the host id
            my $sth =
              $dbh->prepare('SELECT host_id FROM interfaces WHERE address=?');

            if ( !$sth->execute($address) ) {
                $results{"ERROR$counter"} = $MSG_PROG_ERR;
                $counter++;
                next;
            }

            #    once we have the id we can just call the info_function
            while ( my $reference = $sth->fetchrow_hashref ) {
                my %data = %{$reference};
                my @info =
                  Inventory::Hosts::get_hosts_info( $dbh, $data{'host_id'} );
                $results{ $data{'host_id'} } = \%{ $info[0] };
            }
        }
        return \%results;
    }

    if ( $fieldname eq 'host_id' ) {

        # oh, well, that's an easy one
        my @info = Inventory::Hosts::get_hosts_info( $dbh, $value );
        $results{$value} = \%{ $info[0] };
        return \%results;
    }

    # shouldn't get here
    return { 'ERROR' => $MSG_PROG_ERR };
}

=pod

=head2 update_time

Update the time the hosts details were last confirmed

 update_time ( $dbh, $posts );

Returns the details in a hash.

=cut

sub update_time {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    # if you've made it this far you are not the weakest link
    my $sth = $dbh->prepare('UPDATE hosts SET lastchecked = NOW() WHERE id=?');

    if ( !$sth->execute( $posts->{'host_id'} ) ) {
        return { 'ERROR' => 'Internal Error: The update was unsuccessful' };
    }

    return { 'SUCCESS' => 'Thanks for confirming this hosts details' };
}

=pod

=head2 get_hosts_info_by_name 

Given the name of a host, retrieve all information about it
 get_hosts_info_by_name ( $dbh, $host_name );

Search is case insensitive.

Returns the details in a hash.

=cut

sub get_hosts_info_by_name {
    my ( $dbh, $host_name ) = @_;

    return if !defined $dbh;
    return if !defined $host_name;

    my $sth = $dbh->prepare('SELECT * FROM hosts WHERE name ILIKE ?');
    return if !$sth->execute($host_name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 get_hosts_info

Main record retrieval sub. 
 get_hosts_info ( $dbh, $host_id )

$host_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

=cut

sub get_hosts_info {
    my $dbh     = shift;
    my $host_id = shift;
    my $sth;

    return if !defined $dbh;

    if ( defined $host_id ) {
        $sth = $dbh->prepare(
            'SELECT 
           hosts.id,
           hosts.name,
           hosts.description,
           hosts.location_id,
           hosts.status_id,
           hosts.asset,
           hosts.serial,
           hosts.model_id,
           hosts.lastchecked,
           status.state AS status_state,
           status.description AS status_description,
           locations.name AS location_name,
           models.name AS model_name,
           manufacturers.name AS manufacturer_name,
           manufacturers.id AS manufacturer_id,
           hosts.invoice_id,
           invoices.date AS invoice_date,
           invoices.description AS invoice_description,
           contracts.id AS contract_id,
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS contract_enddate_daysremaining,
           contracts.enddate AS contract_enddate,
           contracts.name AS contract_name
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
          LEFT JOIN invoices
          ON hosts.invoice_id=invoices.id
          LEFT JOIN hoststocontracts
          ON hoststocontracts.host_id=hosts.id
          LEFT JOIN contracts
          ON hoststocontracts.contract_id=contracts.id
         
         WHERE
           hosts.id=?
         ORDER BY
           hosts.name
        '
        );
        return if !$sth->execute('days','days',$host_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           hosts.id,
           hosts.name,
           hosts.description,
           hosts.location_id,
           hosts.status_id,
           hosts.asset,
           hosts.serial,
           hosts.model_id,
           hosts.lastchecked,
           status.state AS status_state,
           status.description AS status_description,
           locations.name AS location_name,
           models.name AS model_name,
           manufacturers.name AS manufacturer_name,
           manufacturers.id AS manufacturer_id,
           hosts.invoice_id,
           invoices.date AS invoice_date,
           invoices.description AS invoice_description,
           contracts.id AS contract_id,
           date_part(?, date_trunc(?, (contracts.enddate - now()))) AS contract_enddate_daysremaining,
           contracts.enddate AS contract_enddate,
           contracts.name AS contract_name
         FROM hosts 
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
          LEFT JOIN invoices
          ON hosts.invoice_id=invoices.id
          LEFT JOIN hoststocontracts
          ON hoststocontracts.host_id=hosts.id
          LEFT JOIN contracts
          ON hoststocontracts.contract_id=contracts.id
         
         ORDER BY
           hosts.name
        '
        );
        return if !$sth->execute('days','days');
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

=pod

=head2 delete_hosts

Delete a single host.

 delete_host( $dbh, $host_id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_hosts {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM hosts WHERE id=?');
    if ( !$sth->execute($id) ) {
        return { 'ERROR' => $MSG_DELETE_ERR };
    }

    return { 'SUCCESS' => $MSG_DELETE_OK };
}

1;
__END__

=pod

=head1 DIAGNOSTICS

Via error messages where present.

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
