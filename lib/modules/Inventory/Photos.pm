package Inventory::Photos;
use strict;
use warnings;

our $VERSION = qw('0.0.1');
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_photos
  delete_photos
  edit_photos
  get_photos_info
  upload_photos
  get_photos_byhostid
);

use Carp;
use DBI;
use DBD::Pg;
use Digest::MD5;
use Regexp::Common qw /net/;
use File::Basename;

sub create_photos {
    my ( $dbh, $posts ) = @_;
    my %message;

    if (
        !exists $posts->{'photo_url'}
        || $posts->{'photo_url'} =~
        m/[^\w\-\:\/\.]/x    #not perfect but ok for now
        || length( $posts->{'photo_url'} ) < 1
        || length( $posts->{'photo_url'} ) > 254

        || !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1
      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          "Input Error: check your input or query a possible programming error";
        return \%message;
    }

    # table constraints mean that false ids will be rejected, so I've not done
    # a belts and braces check of the same thing beforehand
    my $sth = $dbh->prepare('INSERT INTO photos(host_id,url) VALUES(?,?)');

    if ( !$sth->execute( $posts->{'host_id'}, $posts->{'photo_url'} ) ) {
        $message{'ERROR'} =
          "Internal Error: The interface creation was unsuccessful";
        return \%message;
    }

    $message{'SUCCESS'} = "The interface creation was successful";
    return \%message;
}

sub edit_photos {
    my ( $dbh, $posts ) = @_;
    my %message;

    # dump bad inputs
    if (
           !exists $posts->{'host_id'}
        || $posts->{'host_id'} =~ m/\D/x
        || length( $posts->{'host_id'} ) < 1

        || !exists $posts->{'photo_url'}
        || $posts->{'photo_url'} =~
        m/[^\w\-\:\/\.]/x    #not perfect but ok for now
        || length( $posts->{'photo_url'} ) < 1
        || length( $posts->{'photo_url'} ) > 254

        || !exists $posts->{'photo_id'}
        || $posts->{'photo_id'} =~ m/\D/x
        || length( $posts->{'photo_id'} ) < 1

      )
    {

        # dont wave bad inputs at the database
        $message{'ERROR'} =
          "Input Error: One of the supplied inputs was invalid.";
        return \%message;
    }

    my $sth = $dbh->prepare('UPDATE photos SET host_id=?,url=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'photo_url'},
            $posts->{'photo_id'}
        )
      )
    {
        $message{'ERROR'} =
          "Internal Error: The interface edit was unsuccessful.";
        return \%message;
    }

    $message{'SUCCESS'} = "Your changes were commited successfully";
    return \%message;
}

sub get_photos_info {
    my ( $dbh, $photo_id ) = @_;
    my $sth;

    return if !defined $dbh;

    if ( defined $photo_id ) {
        $sth = $dbh->prepare(
            'SELECT 
         photos.id,
         photos.host_id,
         photos.url,
         hosts.name AS host_name,
         hosts.status_id,
         status.state
       FROM 
         hosts,photos,status 
       WHERE 
         photos.host_id=hosts.id
         AND status.id = hosts.status_id
         AND photo_id=?
       ORDER BY host_name
        '
        );
        return if !$sth->execute($photo_id);
    }
    else {
        $sth = $dbh->prepare(
            'SELECT 
         photos.id,
         photos.host_id,
         photos.url,
         hosts.name AS host_name,
         hosts.status_id,
         status.state
       FROM 
         hosts,photos,status
       WHERE
         photos.host_id=hosts.id 
         AND status.id = hosts.status_id
       ORDER BY host_name
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

sub get_photos_byhostid {

    # show me all photos that belong to host X
    my ( $dbh, $host_id ) = @_;

    return if !defined $dbh;
    return if !defined $host_id;

    my $sth = $dbh->prepare(
        'SELECT photos.id, photos.url FROM photos WHERE photos.host_id=?');

    return if !$sth->execute($host_id);

    my @return_array;
    while ( my $reference = $sth->fetchrow_hashref ) {
        push @return_array, $reference;
    }
    return @return_array;
}

sub upload_photos {
    my %message;
    my $dbh              = shift;
    my $type             = shift;
    my $upload_extension = shift;
    my $upload_dir       = shift;
    my $website          = shift;
    my $image_path       = shift;
    my %POSTS            = %{ shift() };

    my $query = CGI->new();

    my $original_name = $query->param("$type$upload_extension");
    my ( $name, $path, $extension ) = fileparse( $original_name, '\..*' );

    # taints mode belts braces
    $POSTS{'host_id'} =~ s/\D//gx;
    $upload_extension =~ s/\W//gx;
    $extension        =~ s/[^a-zA-Z]//gx;

    # FIXME: no, apparently still tainted
    # need to match and then extract the matched var
    #

    my $fh = CGI::upload("$type$upload_extension");
    if ( defined $fh ) {

        my $host_id  = $POSTS{'host_id'};
        my $filename = "host_$host_id.$extension";

        my $md5 = Digest::MD5->new->addfile(*$fh)->hexdigest;

        # FIXME md5 causes the file read to fail
        seek $fh, 0, 0;

        # You dirty dirty hack you, oh yes
        # my $md5 = int( rand(10000000000) );

        open my $UPLOADFILE, '>', "$upload_dir/$md5-$filename" or croak $!;
        binmode $UPLOADFILE;

        # Copy a binary file to somewhere safe
        my $buffer;
        while ( my $bytesread = read $fh, $buffer, 1024 ) {
            print $UPLOADFILE $buffer;
        }
        close $UPLOADFILE;

        $POSTS{'photo_url'} = "$website/$image_path/$md5-$filename";

        # create a new entry?
        %message = %{ create_photos( $dbh, \%POSTS ) };
    }
    else {
        $message{'ERROR'} =
"Internal Error: Although a file name was present, no file was uploaded by the browser";
    }

    return \%message;
}

sub delete_photos {

    # delete a single photo

    my ( $dbh, $id ) = @_;
    my %message;

    if ( not defined $id or $id !~ m/^[\d]+$/x ) {

        # could be an error we've made or someone trying to be clever with
        # altering the submission.
        $message{'ERROR'} =
          'Programming Error: Possible issue with the submission form';
        return \%message;
    }

    my $sth = $dbh->prepare('DELETE FROM photos WHERE id=?');
    if ( !$sth->execute($id) ) {
        $message{'ERROR'} =
          'Internal Error: The photo url entry could not be deleted';
        return \%message;
    }

    $message{'SUCCESS'} = 'The specified photo url entry was deleted';
    return \%message;
}

1;

__END__

=head1 NAME

Inventory - Networks team inventory module

=head2 VERSION

This document describes Inventory version 0.0.1

=head1 SYNOPSIS

  use Inventory;

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
