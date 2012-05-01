package Inventory::Hosts;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
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
  hash_hosts_permodel
  hosts_bymodel_name
);

use DBI;
use DBD::Pg;
use Regexp::Common qw /net/;
use Socket;    # in order to lookup a host by dns name
use Net::DNS;

sub create_hosts {
    my $dbh   = shift;
    my %posts = %{ shift() };
    my %message;

    if (
           !exists $posts{'host_name'}
        || $posts{'host_name'} =~ m/[^\w\s\-]/x
        || length( $posts{'host_name'} ) < 1
        || length( $posts{'host_name'} ) > 30

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
        $message{'ERROR'} =
          'Input Error: need Name, Status, Model and Location';
        return \%message;
    }

    $posts{'host_description'} =~ s/[^\w\s\-]//gx
      if exists $posts{'host_description'}
          and defined $posts{'host_description'};
    $posts{'host_name'} = lc $posts{'host_name'};

    if (   not exists $posts{'invoice_id'}
        or not defined $posts{'invoice_id'}
        or length $posts{'invoice_id'} < 1 )
    {
        $posts{'invoice_id'} = undef;
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
            $posts{'host_name'},        $posts{'location_id'},
            $posts{'status_id'},        $posts{'model_id'},
            $posts{'host_description'}, $posts{'host_asset'},
            $posts{'host_serial'},      $posts{'invoice_id'},
        )
      )
    {
        $message{'ERROR'} =
          'Internal Error: The hosts creation was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'The hosts creation was successful';
    return \%message;
}

sub edit_hosts {
    my $dbh   = shift;
    my %posts = %{ shift() };
    my %message;

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
        $message{'ERROR'} = 'Input Error: Please check your inputs';
        return \%message;
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
        $message{'ERROR'} = 'Internal Error: The hosts edit was unsuccessful';
        return \%message;
    }

    $message{'SUCCESS'} = 'Your host changes were commited successfully';
    return \%message;
}

sub host_info_wrapper {
    my ( $dbh, $fieldname, $value ) = @_;
    my %results;    # return results
                    # structure is host_id => @hostdetails

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
    my %message;

    if ( !defined $dbh ) {
        $message{'ERROR'} =
          'Internal Error: Programmer made a mistake in update_time.';
        return \%message;
    }

    if (   !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1 )
    {
        $message{'ERROR'} =
"Possible Input Error: The supplied host id doesn't appear syntatically valid.";
        return \%message;
    }

    # if you've made it this far you are not the weakest link
    my $sth = $dbh->prepare('UPDATE hosts SET lastchecked = NOW() WHERE id=?');

    if ( !$sth->execute( $posts->{'host_id'} ) ) {
        $message{'ERROR'} =
          "Internal Error: The database appears to have rejected this update";
        return \%message;
    }
    else {
        $message{'SUCCESS'} = "Thanks for confirming this hosts details";
        return \%message;
    }

    $message{'ERROR'} =
"Internal Error: Part of the program that's supposed to be logically impossible to reach has just been reached. Things are only likely to go downhill from here.";
    return \%message;
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

    my $sth = $dbh->prepare('DELETE FROM hosts WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The contact entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specificed entry was deleted';
    return \%message;
}

sub hash_hosts_permodel {
    my ($dbh) = @_;

    return if !defined $dbh;

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
         
         ORDER BY
           hosts.name
        
        ' );
    return unless $sth->execute();

    my %return;
    while ( my $ref = $sth->fetchrow_hashref ) {
        if ( !exists( $return{ $ref->{'model_name'} } ) ) {
            my @data = ($ref);
            $return{ $ref->{'model_name'} } = \@data;
        }
        else {
            push @{ $return{ $ref->{'model_name'} } }, $ref;
        }
    }

    return \%return;
}

sub hosts_bymodel_name {
    my ( $dbh, $name ) = @_;

    return if !defined $dbh;
    return if !defined $name;

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
         
         WHERE models.name=?

         ORDER BY
           hosts.name
        ' );

    return unless $sth->execute($name);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;

}

1;
__END__

=head1 NAME

Inventory::Hosts - Networks team inventory module

=head2 VERSION

This document describes Inventory version 1.0.0

=head1 SYNOPSIS

  use Inventory::Hosts;

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
