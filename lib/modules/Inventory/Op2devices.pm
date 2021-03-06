package Inventory::Op2devices;

use strict;
use warnings;

=pod

=head1 NAME

Inventory::Op2devices

=head1 VERSION

This document describes Inventory::Op2devices version 1.02

=head1 SYNOPSIS

  use Inventory::Op2devices;

=head1 DESCRIPTION

Module to handle the data relating to OWL Phase II Devices.

=cut

our $VERSION = '1.02';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_devices
  edit_devices
  get_devices_info
  delete_devices
);

=pod

=head1 DEPENDENCIES

DBI
DBD::Pg
Oxford::Directory
Readonly
Regexp::Common
Inventory::Hosts 1.0

=cut

use DBI;
use DBD::Pg;
use Oxford::Directory;
use Readonly;
use Regexp::Common qw /net/;

use Inventory::Hosts 1.0;

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

Readonly my $ENTRY            => 'Owl Phase II device';
Readonly my $CISCO_MAC_LENGTH => '14';
Readonly my $BARE_MAC_LENGTH  => '12';

Readonly my $MSG_DBH_ERR    => 'Internal Error: Lost the database connection';
Readonly my $MSG_INPUT_ERR  => "Please check your $ENTRY data input";
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

=head2 clean_inputs

Attempt to put the input cleaning logic in one place

=cut

sub clean_inputs {
    my %input     = %{ shift() };
    my $amspecial = shift;
    my @message_store;

    # mac
    if ( !defined $input{'mac'} || length( $input{'mac'} ) < 1 ) {
        my %message;
        $message{'ERRORmac'} = 'No mac address was passed on';
        $message{'FATAL'}    = $MSG_FATAL_ERR;
        push @message_store, \%message;
        return \@message_store, \%input;
    }
    else {
        $input{'mac'} =~ s/\s//;

        if ( length( $input{'mac'} ) == $CISCO_MAC_LENGTH
            && $input{'mac'} =~ m/\./ )
        {

            # cisco style mac address
            $input{'mac'} =~ s/\.//g;

            # next statement will format this, saves us code again
        }

        if ( length( $input{'mac'} ) == $BARE_MAC_LENGTH ) {

            # mac addess with no punctuation, regex common hates that. Lets
            # lend a helping hand
            $input{'mac'} =~ s/(\w{2})/$1:/g;

            # we just created a trailing : by accident, chop it off
            $input{'mac'} =~ s/:$//;
        }

        if ( $input{'mac'} !~ m/^$RE{net}{MAC}$/ ) {
            my %message;
            $message{ERRORmac} = 'Badly formatted Mac addess';
            $message{'FATAL'} = $MSG_FATAL_ERR;
            push @message_store, \%message;
            return \@message_store, \%input;
        }
    }

    # name requested to be the same as mac address
    # I just work here gov
    #
    $input{'name'} = $input{'mac'};

    # we need their unit: this is a little more complex than you might think
    #
    # The spec for writing this says that IT officers can only spec their unit
    # as the ocrresponding unit for their device. So. We need to check again
    # now that they've submitted the form that they haven't been a little
    # crafty. Specifically does the unit they've specificed for the device
    # match a unit they are associated with? Also if they are one of our
    # chosen special ones then they bypass this check.

    if ( !defined $input{'unit'} ) {
        my %message;
        $message{'ERRORunit'} =
          'No unit was received to be associated with the device';
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
        return \@message_store, \%input;
    }

    # find our user
    # FIXME: RFC - do we want to use $ENV{REMOTE_USER} or do we pass this to the
    # subroutine?
    #
    my $directory = Oxford::Directory->new;

    # get user object
    my $user = $directory->people->by_principal( $ENV{'REMOTE_USER'} )
      or return { 'ERROR' => 'failed to find person ['
          . ( $ENV{'REMOTE_USER'} || '(null)' )
          . '] in Oak LDAP' };

    # set starting positions
    my $validunit = 'false';

    # find users units
    if ( $amspecial eq 'false' ) {

        # units this ITSS can manage
        foreach my $unitcode ( $user->get_itss_for ) {
            if ( $input{'unit'} eq $unitcode->oakunitcode ) {
                $validunit = 'true';
            }
            my $shortname = $unitcode->oakunitcode;
        }

    }

    if ( $amspecial eq 'false' && $validunit eq 'false' ) {
        my %message;
        $message{'ERRORunit'} =
"$ENV{'REMOTE_USER'} is not known to be associated with the submitted unit for the device";
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
        return \@message_store, \%input;
    }

    # are we special?
    if ( $amspecial eq 'true' ) {
        if (  !defined $input{'oucs_owned'}
            || length( $input{'oucs_owned'} ) < 1 )
        {
            $input{'oucs_owned'} = 'false';
        }
        elsif ( $input{'oucs_owned'} ne 'true' ) {
            $input{'oucs_owned'} = 'false';
        }
    }
    else {

        # cant trust user supplied settings
        #
        $input{oucs_owned} = 'false';

        # FIXME hardcoded = badmkay?
        # db id 1 = active;
        # db id 2 = inactive;
        $input{status} = '2';
    }

    return \@message_store, \%input;
}

=pod

=head2 create_devices

Main creation sub.
create_devices($dbh, $priv_level, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Permissions in complicated as this page is for general IT staff access who
need to be limited to their unit

=cut

sub create_devices {
    my $dbh       = shift;
    my $amspecial = shift;
    my %posts     = %{ shift() };

    # unit
    # building
    # room
    # status_id (auto set)

    my ( $ref1, $ref2 ) = clean_inputs( \%posts, $amspecial );
    my @message_store = @{$ref1};
    %posts = %{$ref2};

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return \@message_store;
        }
    }

    my $sth = $dbh->prepare('SELECT mac FROM owlphase2_devices WHERE mac=?');
    if ( !$sth->execute( $posts{'mac'} ) ) {
        my %message;
        $message{'ERROR'} =
'Internal Error: Unable to check if this record already exists due to a programming mistake or similar';
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
        return \@message_store;
    }

    my $dupcount = 0;
    while ( my $reference = $sth->fetchrow_hashref ) {
        $dupcount++;
    }
    if ( $dupcount > 0 ) {
        my %message;
        $message{'ERROR'} =
"The mac address $posts{'mac'} has already been added, it will not be added more than once";
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
        return \@message_store;
    }

    $sth = $dbh->prepare( '
                             INSERT INTO owlphase2_devices(
                                 mac,
                                 building,
                                 room,
                                 oucs_owned,
                                 name,
                                 unit,
                                 status_id
                                 ) VALUES(?,?,?,?,?,?,?)' );

    if (
        !$sth->execute(
            $posts{'mac'},        $posts{'building'}, $posts{'room'},
            $posts{'oucs_owned'}, $posts{'name'},     $posts{'unit'},
            $posts{'status'},
        )
      )
    {
        my %message;
        $message{'ERROR'} =
          'Internal Error: The device creation was unsuccessful';
        $message{'FATAL'} = $MSG_FATAL_ERR;
        push @message_store, \%message;
        return \@message_store;
    }

    my %message;
    $message{'SUCCESS'} = 'The device creation was successful';
    push @message_store, \%message;
    return \@message_store;
}

=pod

=head2 edit_XXX

Main edit sub.
  edit_XXX ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

For the XXX name we strip leading and trailing whitespace to make life
easier for people pasting in model names from manufacturers websites and
similar.

Currently the only error check is for a missing database handle.

=cut

sub edit_devices {

    # similar to creating a model
    # except we already (should) have a vaild database id
    # for the entry
    #
    my $dbh       = shift;
    my $amspecial = shift;
    my %posts     = %{ shift() };

    my %message;

    my ( $ref1, $ref2 ) = clean_inputs( \%posts, $amspecial );
    my @message_store = @{$ref1};
    %posts = %{$ref2};

    foreach my $message (@message_store) {
        my %temp_hash = %{$message};
        if ( $temp_hash{'FATAL'} ) {
            return \@message_store;
        }
    }

    # If they aren't a special user then we need to change the edit SQL to not
    # update certin fields
    #
    # if they aren't special, check they can actually edit that
    # device_id
    # 1) lookup the device, get the unit
    # 2) gets the persons units
    # 3) check: does 2 contain 1?
    # no -> die! die! die!, or at least an error message
    # yes -> everything seems in order Mr Bond, please continue
    #
    # FIXME: RFC - do we want to use $ENV{REMOTE_USER} or do we pass this to the
    # subroutine?
    #

    my $directory = Oxford::Directory->new;

    # get user object
    my $user = $directory->people->by_principal( $ENV{'REMOTE_USER'} )
      or return { 'ERROR' => 'failed to find person ['
          . ( $ENV{'REMOTE_USER'} || '(null)' )
          . '] in Oak LDAP' };

    # set starting positions
    if ( $amspecial ne 'false' && $amspecial ne 'true' ) {
        $message{'ERROR'} = $MSG_PROG_ERR;
        push @message_store, \%message;
        return \@message_store;
    }
    my $validunit = 'false';

    my $sth = $dbh->prepare('SELECT unit from owlphase2_devices WHERE id = ?');
    if ( !$sth->execute( $posts{'device_id'} ) ) {
        $message{'ERROR'} =
          'Internal Error: Cant check the unit for the supplied database entry';
        push @message_store, \%message;
        return \@message_store;
    }

    # assumption: you don't get more than one result from your query, if you
    # do that unique id isn't so unique any more and someone has been playing
    # with the database table
    #
    my $queriedunit;
    while ( my $reference = $sth->fetchrow_hashref ) {
        $queriedunit = $reference->{'unit'};
    }

    # units this ITSS can manage
    my %myunits = ();
    foreach my $unitcode ( $user->get_itss_for ) {
        $myunits{$unitcode} = $unitcode->displayname;
        if ( $posts{'unit'} eq $unitcode->oakunitcode ) {
            $validunit = 'true';
        }
        my $shortname = $unitcode->oakunitcode;

    }

    # change the query if they aren't special
    if ( $validunit eq 'true' && $amspecial eq 'false' ) {
        my $sth2 = $dbh->prepare(
            'UPDATE owlphase2_devices SET
                                 mac        =?,
                                 building   =?,
                                 room       =?,
                                 unit       =?
                                 WHERE id =?'
        );

        if (
            !$sth2->execute(
                $posts{'mac'},  $posts{'building'}, $posts{'room'},
                $posts{'unit'}, $posts{'device_id'}
            )
          )
        {
            return { 'ERROR' => $MSG_EDIT_ERR };
        }
        elsif ( $validunit eq 'false' && $amspecial eq 'false' ) {
            $message{'ERROR'} =
'You do not appear to be associated with the unit for the device you are attempting to edit.';
            push @message_store, \%message;
            return \@message_store;
        }
    }
    elsif ( $amspecial eq 'true' ) {

        my $sth2 = $dbh->prepare(
            'UPDATE owlphase2_devices SET
                                 mac        =?,
                                 building   =?,
                                 room       =?,
                                 oucs_owned =?,
                                 unit       =?,
                                 status_id  =?
                                 WHERE id =?'
        );

        if (
            !$sth2->execute(
                $posts{'mac'},  $posts{'building'},
                $posts{'room'}, $posts{'oucs_owned'},
                $posts{'unit'}, $posts{'status'},
                $posts{'device_id'}
            )
          )

        {
            return { 'ERROR' => $MSG_EDIT_ERR };
        }
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_devices_info

Main individual record retrieval sub. 
 get_devices_info ( $dbh, $principal, $priv, $device_id )

$device_id is optional, if not specified all results will be returned.

Returns the details in a array of hashes.

If they are a superuser they are show all access points, otherwise we look up
which units they are ITSS for and only show them these units access points.

=cut

sub get_devices_info {
    my $dbh       = shift;
    my $principal = shift;
    my $amspecial = shift;
    my $device_id = shift;
    my $sth;

    return if !defined $dbh;

    if ( defined $device_id ) {
        $sth = $dbh->prepare(
            'SELECT 
           owlphase2_devices.id,
           owlphase2_devices.name,
           owlphase2_devices.unit,
           owlphase2_devices.serial,
           owlphase2_devices.oucs_owned,
           owlphase2_devices.building,
           owlphase2_devices.room,
           owlphase2_devices.ip_address,
           owlphase2_devices.connected_switch,
           owlphase2_devices.connected_switch_port,
           owlphase2_devices.mac,
           status.id AS status_id,
           status.state AS status_state
        FROM owlphase2_devices,status
        WHERE
           status.id = owlphase2_devices.status_id
           AND owlphase2_devices.id = ?
        ORDER BY 
           owlphase2_devices.name
        '
        );
        return if !$sth->execute($device_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
           owlphase2_devices.id,
           owlphase2_devices.name,
           owlphase2_devices.unit,
           owlphase2_devices.serial,
           owlphase2_devices.oucs_owned,
           owlphase2_devices.building,
           owlphase2_devices.room,
           owlphase2_devices.ip_address,
           owlphase2_devices.connected_switch,
           owlphase2_devices.connected_switch_port,
           owlphase2_devices.mac,
           status.id AS status_id,
           status.state AS status_state
        FROM owlphase2_devices,status
        WHERE
           status.id = owlphase2_devices.status_id
        ORDER BY
           owlphase2_devices.unit,
           owlphase2_devices.building,
           owlphase2_devices.room,
           owlphase2_devices.mac
        '
        );
        return if !$sth->execute();
    }

    # need to know their units first
    #
    my $directory = Oxford::Directory->new;

    # get user object
    my $user = $directory->people->by_principal($principal)
      or return { 'ERROR' => 'failed to find person ['
          . ( $principal || '(null)' )
          . '] in Oak LDAP' };

    # units this ITSS can manage
    my @units = qw();
    foreach my $unitcode ( $user->get_itss_for ) {
        my $shortname = $unitcode->oakunitcode;
        push @units, $shortname;
    }

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {

        # the priviliged elite avoid the hassle
        if ( $amspecial eq 'true' ) {
            push @return_array, $reference;
            next;
        }

        # otherwise you only get the result if its a unit you are associated
        # with...
        #
        # FIXME: bit inefficient
        my $validunit = 'false';
        foreach my $unit (@units) {
            if ( $reference->{'unit'} eq $unit ) {
                $validunit = 'true';
            }
        }
        if ( $validunit eq 'true' ) {
            push @return_array, $reference;
        }
    }

    return @return_array;
}

=pod

=head2 delete_devices

Delete a single devices.

 delete_devices( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_devices {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM owlphase2_devices WHERE id=?');
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
