package Inventory::Hosts;
use strict;
use warnings;

=pod

=head1 NAME

  Inventory::Hosts

=head2 VERSION

This document describes Inventory::Hosts version 1.01

=head1 SYNOPSIS

  use Inventory::Hosts;

=head1 DESCRIPTION

Functions for dealing with the Hosts table related data

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_hosts
  edit_hosts
  delete_hosts
  get_hosts_info
  get_hosts_info_by_name
  host_info_wrapper
  update_time
  get_hosts_byinvoice
);

use DBI;
use DBD::Pg;
use Net::DNS;

my $ENTRY          = 'host';
my $MSG_DBH_ERR    = 'Internal Error: Lost the database connection';
my $MSG_INPUT_ERR  = 'Input Error: Please check your input';
my $MSG_CREATE_OK  = "The $ENTRY creation was successful";
my $MSG_CREATE_ERR = "The $ENTRY creation was unsuccessful";
my $MSG_EDIT_OK    = "The $ENTRY edit was successful";
my $MSG_EDIT_ERR   = "The $ENTRY edit was unsuccessful";
my $MSG_DELETE_OK  = "The $ENTRY entry was deleted";
my $MSG_DELETE_ERR = "The $ENTRY entry could not be deleted";
my $MSG_FATAL_ERR  = 'The error was fatal, processing stopped';

sub create_hosts {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (
           !exists $posts->{'host_name'}
        || $posts->{'host_name'} =~ m/[^\w\s\-]/x
        || length( $posts->{'host_name'} ) < 1
        || length( $posts->{'host_name'} ) > 30

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

    $posts->{'host_description'} =~ s/[^\w\s\-]//gx
      if exists $posts->{'host_description'}
          and defined $posts->{'host_description'};
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

sub edit_hosts {
    my $dbh   = shift;
    my %posts = %{ shift() };

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (
           !exists $posts{'host_name'}
        || $posts{'host_name'} =~ m/[^\w\s\-]/x
        || length( $posts{'host_name'} ) < 1
        || length( $posts{'host_name'} ) > 30

        || !exists $posts{'host_id'}
        || $posts{'host_id'} =~ m/\D/x
        || length( $posts{'host_id'} ) < 1

        || !exists $posts{'location_id'}
        || $posts{'location_id'} =~ m/\D/x
        || length( $posts{'location_id'} ) < 1

        || !exists $posts{'status_id'}
        || $posts{'status_id'} =~ m/\D/x
        || length( $posts{'status_id'} ) < 1

        || !exists $posts{'model_id'}
        || $posts{'model_id'} =~ m/\D/x
        || length( $posts{'model_id'} ) < 1
      )
    {

        # dont wave bad inputs at the database
        return { 'ERROR' => 'Input Error: Please check your input' };
    }

    if (   not exists $posts{'invoice_id'}
        or not defined $posts{'invoice_id'}
        or length $posts{'invoice_id'} < 1 )
    {
        $posts{'invoice_id'} = undef;
    }

    $posts{'host_description'} =~ s/[^\w\s\-]//gx
      if exists $posts{'host_description'}
          and defined $posts{'host_description'};
    $posts{'host_name'} = lc $posts{'host_name'};

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
            $posts{'host_name'},        $posts{'location_id'},
            $posts{'status_id'},        $posts{'model_id'},
            $posts{'host_description'}, $posts{'host_asset'},
            $posts{'host_serial'},      $posts{'invoice_id'},
            $posts{'host_id'}
        )
      )
    {
        return { 'ERROR' => 'Internal Error: The edit was unsuccessful' };
    }

    return { 'SUCCESS' => 'Your host changes were commited successfully' };
}

sub host_info_wrapper {
    my ( $dbh, $fieldname, $value ) = @_;
    my %results;    # return results
                    # structure is host_id => @hostdetails

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    # generic error
    my $error =
'Internal Error: The database lookup failed - likely to be a database or programming issue';

    if ( $fieldname eq 'asset' ) {
        my $sth = $dbh->prepare('SELECT id FROM hosts WHERE asset=?');

        if ( !$sth->execute($value) ) {

            # Something went horribly wrong
            # Check the apache logs for the exact details
            # I'm not showing the user the exact error
            $results{'ERROR'} = $error;
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
        my $sth = $dbh->prepare('SELECT id FROM hosts WHERE name ILIKE ?');

        if ( !$sth->execute($value) ) {
            $results{'ERROR'} = $error;
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

    if ( $fieldname eq 'serial' ) {
        my $sth = $dbh->prepare('SELECT id FROM hosts WHERE serial=?');

        if ( !$sth->execute($value) ) {
            $results{'ERROR'} = $error;
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
                next unless $rr->type eq "A";
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
                $results{'ERROR'} = $error;
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
                $results{"ERROR$counter"} = $error;
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

    $error =
"Internal Error: A condition the programmer thought would never happen, did. (fieldname was $fieldname)";
    $results{'ERROR'} = $error;
    return \%results;
}

sub update_time {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    if (   !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1 )
    {
        return {
            'ERROR' => 'Programming Error: The supplied host id is invalid' };
    }

    # if you've made it this far you are not the weakest link
    my $sth = $dbh->prepare('UPDATE hosts SET lastchecked = NOW() WHERE id=?');

    if ( !$sth->execute( $posts->{'host_id'} ) ) {
        return { 'ERROR' => 'Internal Error: The update was unsuccessful' };
    }

    return { 'SUCCESS' => 'Thanks for confirming this hosts details' };
}

sub get_hosts_info_by_name {
    my ( $dbh, $host_name ) = @_;

    return if !defined $dbh;
    return if !defined $host_name;

    my $sth = $dbh->prepare('SELECT * FROM hosts WHERE name ILIKE ?');
    return unless $sth->execute($host_name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub get_hosts_byinvoice {
    my ( $dbh, $id ) = @_;

    return if !defined $dbh;
    return if !defined $id;

    my $sth = $dbh->prepare( '
         SELECT 
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
           manufacturers.id AS manufacturer_id
         FROM hosts
          
          LEFT JOIN locations
          ON hosts.location_id=locations.id
          LEFT JOIN status
          ON hosts.status_id=status.id
          LEFT JOIN models
          ON hosts.model_id=models.id
          LEFT JOIN manufacturers
          ON manufacturers.id=models.manufacturer_id
         
         WHERE
           invoice_id=?
         ORDER BY
           hosts.name
        
        ' );
    return unless $sth->execute($id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

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
           invoices.description AS invoice_description
           contracts.id AS contract_id,
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
        return if !$sth->execute($host_id);
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
           invoices.description AS invoice_description
           contracts.id AS contract_id,
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
        return if !$sth->execute();
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

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
