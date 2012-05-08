package Inventory::Edithost;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Edithost

=head1 VERSION

This document describes Inventory::Edithost version 1.01

=head1 SYNOPSIS

  use Inventory::Edithost;

=head1 DESCRIPTION

Functions for dealing with editing multiple aspects of the hosts data at once

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  do_update_all
);

=pod

=head1 DEPENDENCIES

NetAddr::IP
Regexp::Common
Readonly

Inventory::Hosts
Inventory::Interfaces 1.03
Inventory::Locations
Inventory::Ups
Inventory::Introlemembers
Inventory::Cnames 1.03

=cut

use NetAddr::IP;
use Regexp::Common 'net';
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

Readonly my $TABLEID_VOIPUPS1 => '43';
Readonly my $TABLEID_VOIPUPS2 => '28';
Readonly my $ENTRY            => 'host';

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

Readonly my $MSG_LOCDB_ERR       => 'Programming error after location creation';
Readonly my $MSG_NO_HN_ERR       => 'No host name was supplied';
Readonly my $MSG_HOST_EXISTS_ERR => 'That host already exists';

=pod

=head1 SUBROUTINES/METHODS

=head2 do_update_all

Main creation sub.
  do_update_all($dbh, \%posts)


This single sub calls all the other inventory primitives to action changes to
the web form (it actually does not notice changes, it just reissues all
current settings)

=cut

sub do_update_all {
    my ( $dbh, $POSTS ) = @_;
    my $messages = [];

    _create_or_update_host( $dbh, $POSTS, $messages );

    return @{$messages} if exists $messages->[-1]->{'ERROR'};

    _update_ups( $dbh, $POSTS, $messages );
    _add_ups( $dbh, $POSTS, $messages );

    _update_interfaces( $dbh, $POSTS, $messages );
    _add_interface( $dbh, $POSTS, $messages );

    return @{$messages};
}

=pod

=head2 _create_or_update_host

Might be used to either create a new host or to update an existing one

Note that we don't update the time all details were last checked as the user
might be updating only one value and doesn't want to/is not able to confirm
all host details at this point.

=cut

sub _create_or_update_host {
    my ( $dbh, $POSTS, $messages ) = @_;

    # create a new location
    if ( $POSTS->{'location_x'} ) {
        push @{$messages},
          Inventory::Locations::create_locations( $dbh,
            { location_name => $POSTS->{'location_x'}, } );
        return if exists $messages->[-1]->{'ERROR'};

        # now grab the ID
        my $loc_id =
          [ grep { $_->{name} eq $POSTS->{'location_x'} }
              Inventory::Locations::get_locations_info($dbh) ]->[0];
        if ( !defined $loc_id ) {
            push @{$messages}, { ERROR => $MSG_LOCDB_ERR };
            return;
        }

        # poke the new location id into the params for this host
        $POSTS->{'location_id'} = $loc_id->{id};
    }

    if ( $POSTS->{'host_id'} ) {
        push @{$messages}, Inventory::Hosts::edit_hosts( $dbh, $POSTS );
    }
    else {

        if ( not exists $POSTS->{'host_name'} ) {
            my %errors;
            $errors{'ERROR'} = $MSG_NO_HN_ERR;
            push @{$messages}, \%errors;
            return @{$messages};
        }
        else {
            my @result =
              Inventory::Hosts::get_hosts_info_by_name( $dbh,
                $POSTS->{'host_name'} );
            if ( $result[0]->{'id'} ) {
                my %errors;
                $errors{'ERROR'} = $MSG_HOST_EXISTS_ERR;
                push @{$messages}, \%errors;
                return @{$messages};
            }
        }

        push @{$messages}, Inventory::Hosts::create_hosts( $dbh, $POSTS );
    }
    return @{$messages} if exists $messages->[-1]->{'ERROR'};

    # we may be creating a new host - update the POSTS hash
    my @new_host =
      Inventory::Hosts::get_hosts_info_by_name( $dbh, $POSTS->{'host_name'} );
    $POSTS->{host_id} = $new_host[0]->{id};

    return @{$messages};
}

=pod

=head2 _update_ups

edit or remove a UPS protection relationship

 _update_ups( $dbh, $POSTS, $messages )

=cut

sub _update_ups {
    my ( $dbh, $POSTS, $messages ) = @_;

    foreach my $field ( grep { m/^ups_id_\d+$/ } keys %$POSTS ) {
        ( my $link_id = $field ) =~ s/^ups_id_(\d+)$/$1/;

        if ( $POSTS->{$field} ) {    # populated field means edit
            push @{$messages},
              Inventory::Ups::edit_ups(
                $dbh,
                {
                    link_id => $link_id,
                    host_id => $POSTS->{'host_id'},
                    ups_id  => $POSTS->{$field},
                }
              );
        }
        else {                       # empty field data means delete
            push @{$messages}, Inventory::Ups::delete_ups( $dbh, $link_id );
        }
    }
    return;
}

=pod

=head2 _add_ups

Create a UPS protection relationship, including creating the UPS host if
needed.

 _add_ups( $dbh, $POSTS, $messages )

=cut

sub _add_ups {
    my ( $dbh, $POSTS, $messages ) = @_;

    # link to an existing ups
    if ( $POSTS->{'ups_id_x'} ) {
        push @{$messages},
          Inventory::Ups::create_ups(
            $dbh,
            {
                host_id => $POSTS->{'host_id'},
                ups_id  => $POSTS->{'ups_id_x'},
            }
          );
        return;
    }

    # or create and link a new ups on the fly
    return if not( $POSTS->{'ups_x'} and $POSTS->{'ups_x_ip'} );

    # sanity clause check for name and ip
    if (   ( $POSTS->{'ups_x'} and not $POSTS->{'ups_x_ip'} )
        or ( $POSTS->{'ups_x_ip'} and not $POSTS->{'ups_x'} ) )
    {

        push @{$messages}, { ERROR => $MSG_PROG_ERR };
        return;
    }

    # we can generate the ups name for network devices
    if ( $POSTS->{'ups_x'} eq 'MAGIC_FRODO_UPS_NAME_COOKIE' ) {
        if ( $POSTS->{'device_type'} eq 'frodo' ) {
            $POSTS->{'ups_x'} = $POSTS->{'host_name'} . '-ups';
        }
        else {
            my $aobj = NetAddr::IP->new( $POSTS->{'ups_x_ip'} );
            if ( $aobj->addr =~ m/^$RE{net}{IPv4}{-keep}$/ ) {
                my ( $oct3, $oct4 ) = ( $4, $5 );
                $POSTS->{'ups_x'} = "sec-ups-$oct3-$oct4";
                $POSTS->{'ups_x_secure'} = 1;    # a flag, for later (role)
            }
        }
    }

    if ( $POSTS->{'host_description'} and not $POSTS->{'ups_x_description'} ) {
        $POSTS->{'ups_x_description'} = $POSTS->{'host_description'} . ' UPS';
    }

    push @{$messages}, Inventory::Hosts::create_hosts(
        $dbh,
        {
            host_name   => $POSTS->{'ups_x'},
            model_id    => $POSTS->{'ups_x_model'},
            status_id   => $POSTS->{'status_id'},      # inherit from this host
            location_id => $POSTS->{'location_id'},    # inherit from this host
            host_description =>
              $POSTS->{'ups_x_description'},           # inherit with mangling
        }
    );
    return if exists $messages->[-1]->{'ERROR'};

    # to add an interface to this ups we need to grab the id back
    my @new_ups =
      Inventory::Hosts::get_hosts_info_by_name( $dbh, $POSTS->{'ups_x'} );
    return if not scalar @new_ups == 1;

    push @{$messages},
      Inventory::Interfaces::create_interfaces(
        $dbh,
        {
            host_id           => $new_ups[0]->{id},
            interface_address => $POSTS->{'ups_x_ip'},
            isprimary         => 'true',
        }
      );
    return if exists $messages->[-1]->{'ERROR'};

    # to add a role to this new ups interface, we need to grab the id back
    my @ups_int = Inventory::Interfaces::get_interfaces_info(
        $dbh,
        undef
        ,    # this is required to trigger the polymorphic subroutine interface
        $new_ups[0]->{id},
        $POSTS->{'ups_x_ip'},
    );
    return if not scalar @ups_int == 1;

    push @{$messages}, Inventory::Introlemembers::create_memberships(
        $dbh,
        {
            host_id =>
              $ups_int[0]->{id}, # interface.id but param is still named host_id
            hostgroup_id => (
                $POSTS->{'ups_x_secure'} ? $TABLEID_VOIPUPS1 : $TABLEID_VOIPUPS2
            ),

            # again, the interface_role.id
            # XXX hard coded table IDs
        }
    );
    return if exists $messages->[-1]->{'ERROR'};

    # now link the new ups to our device
    push @{$messages},
      Inventory::Ups::create_ups(
        $dbh,
        {
            host_id => $POSTS->{'host_id'},
            ups_id  => $new_ups[0]->{id},
        }
      );
    return;
}

=pod

=head2 _update_interfaces

edit and delete interfaces, create interface roles

 _update_interfaces( $dbh, $POSTS, $messages )

=cut

sub _update_interfaces {
    my ( $dbh, $POSTS, $messages ) = @_;

    foreach my $field ( grep { m/^interface_\d+_ip$/ } keys %$POSTS ) {
        ( my $int_id = $field ) =~ s/^interface_(\d+)_ip$/$1/;

        if ( $POSTS->{$field} ) {    # populated field means edit
            push @{$messages},
              Inventory::Interfaces::edit_interfaces(
                $dbh,
                {
                    interface_id      => $int_id,
                    host_id           => $POSTS->{'host_id'},
                    interface_address => $POSTS->{$field},
                    isprimary => $POSTS->{"interface_${int_id}_isprimary"},
                }
              );

            # allow to fail but continue

            # update status of existing role links
            foreach my $role_field (
                grep { m/^interface_${int_id}_role_\d+$/ }
                keys %$POSTS
              )
            {
                ( my $membership_id = $role_field ) =~
                  s/^interface_${int_id}_role_(\d+)$/$1/;

                if ( $POSTS->{$role_field} ) {    # populated field means edit
                    push @{$messages},
                      Inventory::Introlemembers::edit_memberships(
                        $dbh,
                        {
                            host_id       => $int_id,
                            membership_id => $membership_id,
                            hostgroup_id  => $POSTS->{$role_field},
                        }
                      );
                }
                else {    # empty field data means delete
                    push @{$messages},
                      Inventory::Introlemembers::delete_memberships( $dbh,
                        { membership_id => $membership_id, } );
                }
            }

            # add a new role to the interface
            if ( $POSTS->{"interface_${int_id}_role_x"} ) {
                push @{$messages},
                  Inventory::Introlemembers::create_memberships(
                    $dbh,
                    {
                        host_id      => $int_id,
                        hostgroup_id => $POSTS->{"interface_${int_id}_role_x"},
                    }
                  );
            }
        }
        else {    # empty field data means delete
            push @{$messages},
              Inventory::Interfaces::delete_interfaces( $dbh, $int_id );

            # roles will cascade-delete from the interface, so we can
            # ignore their settings in the form on interface deletion.
        }
    }

    # there should be only one arec/cname (template restriction) but just
    # in case, this is a loop (the db prevents as well, I think)...
    foreach my $field ( grep { m/^arec_\d+$/ } keys %$POSTS ) {
        ( my $cname_id = $field ) =~ s/^arec_(\d+)$/$1/;

        if ( $POSTS->{$field} ) {    # populated field means edit
            if ( not $POSTS->{"cname_${cname_id}"} ) {
                push @{$messages},
                  {     ERROR => qq{Alias must be set for Hostname "}
                      . $POSTS->{$field}
                      . qq{". To delete the entry, blank the Hostname field instead.}
                  };
                next;
            }

            push @{$messages},
              Inventory::Cnames::edit_cnames(
                $dbh,
                {
                    host_id   => $POSTS->{'host_id'},
                    dnsname   => lc $POSTS->{$field},
                    shortname => lc $POSTS->{"cname_${cname_id}"},
                    cname_id  => $cname_id,
                }
              );
        }
        else {    # empty field data means delete
            push @{$messages},
              Inventory::Cnames::delete_cnames( $dbh, $cname_id );
        }
    }

    # interface might exist but not have a frodo alias, so we get _x variant
    if ( scalar grep { m/^interface_\d+_ip$/ } keys %$POSTS ) {
        if ( $POSTS->{'arec_x'} and $POSTS->{'cname_x'} ) {
            push @{$messages},
              Inventory::Cnames::create_cnames(
                $dbh,
                {
                    host_id   => $POSTS->{'host_id'},
                    dnsname   => lc $POSTS->{'arec_x'},
                    shortname => lc $POSTS->{'cname_x'},
                }
              );
        }
    }
    return;
}

=pod

=head2 _add_interfaces

add interfaces, create interface roles

 _add_interface( $dbh, $POSTS, $messages )

=cut

sub _add_interface {
    my ( $dbh, $POSTS, $messages ) = @_;
    return if !exists $POSTS->{'interface_x_ip'};

    push @{$messages},
      Inventory::Interfaces::create_interfaces(
        $dbh,
        {
            host_id           => $POSTS->{'host_id'},
            interface_address => $POSTS->{'interface_x_ip'},
            isprimary         => $POSTS->{'interface_x_isprimary'},
        }
      );
    return if exists $messages->[-1]->{'ERROR'};

    if ( $POSTS->{'interface_x_role'} ) {

        # to add a role to this new interface, we need to grab the id back
        my @info = Inventory::Interfaces::get_interfaces_info(
            $dbh,
            undef
            , # this is required to trigger the polymorphic subroutine interface
            $POSTS->{'host_id'},
            $POSTS->{'interface_x_ip'},
        );

        if ( scalar @info == 1 ) {
            push @{$messages}, Inventory::Introlemembers::create_memberships(
                $dbh,
                {
                    host_id => $info[0]
                      ->{id},    # interface.id but param is still named host_id
                    hostgroup_id => $POSTS->{
                        'interface_x_role'},    # again, the interface_role.id
                }
            );
        }
    }

    # the template will show arec and cname fields appropriate to whether
    # existing records are in place or there is/is not a primary interface

    if (   ( $POSTS->{'arec_x'} and not $POSTS->{'cname_x'} )
        or ( not $POSTS->{'arec_x'} and $POSTS->{'cname_x'} ) )
    {
        push @{$messages}, { ERROR => $MSG_INPUT_ERR };
        return;
    }
    elsif ( $POSTS->{'arec_x'} and $POSTS->{'cname_x'} ) {
        push @{$messages},
          Inventory::Cnames::create_cnames(
            $dbh,
            {
                host_id   => $POSTS->{'host_id'},
                dnsname   => lc $POSTS->{'arec_x'},
                shortname => lc $POSTS->{'cname_x'},
            }
          );
    }
    return;
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

[This specific page includes work by Oliver Gorwits]

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
