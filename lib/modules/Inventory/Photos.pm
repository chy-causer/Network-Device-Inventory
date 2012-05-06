package Inventory::Photos;
use strict;
use warnings;

=pod

=head1 NAME

Inventory::Photos

=head1 VERSION

This document describes Inventory::Photos version 1.01

=head1 SYNOPSIS

  use Inventory::Photos;

=head1 DESCRIPTION

Module for manipulation of the photos table

=cut

our $VERSION = '1.01';
use base qw( Exporter);
our @EXPORT_OK = qw(
  create_photos
  delete_photos
  edit_photos
  get_photos_info
  upload_photos
  get_photos_byhostid
);

=pod

=head1 DEPENDENCIES

Carp
DBI
DBD::Pg
Digest::MD5
File::Basename
Readonly

=cut

use Carp;
use DBI;
use DBD::Pg;
use Digest::MD5;
use File::Basename;
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

Readonly my $MAX_URL_LENGTH       => '254';
Readonly my $READ_SIZE_CHARACTERS => '1024';

Readonly my $ENTRY          => 'photo';
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

Readonly my $MSG_FILECLOSE_ERR => 'Internal Error: Unable to close the file';
Readonly my $MSG_UPLOAD_ERR    => 'Internal Error: No file was uploaded';

=head1 SUBROUTINES/METHODS

=head2 create_photos

Main creation sub.
create_photos($dbh, \%posts)

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for a missing database handle and basic url sanity.

=cut

sub create_photos {
    my ( $dbh, $posts ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }
    if (
        !exists $posts->{'photo_url'}
        || $posts->{'photo_url'} =~
        m/[^\w\-\:\/\.]/x    #not perfect but ok for now
        || length( $posts->{'photo_url'} ) < 1
        || length( $posts->{'photo_url'} ) > $MAX_URL_LENGTH
      )
    {
        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare('INSERT INTO photos(host_id,url) VALUES(?,?)');

    if ( !$sth->execute( $posts->{'host_id'}, $posts->{'photo_url'} ) ) {
        return { 'ERROR' => $MSG_CREATE_ERR };
    }

    return { 'SUCCESS' => $MSG_CREATE_OK };
}

=pod

=head2 edit_photos

Main edit sub.
  edit_photos ( $dbh, \%posts );

Returns %hashref of either SUCCESS=> message or ERROR=> message.

Checks for missing ddatabase handle, relevant ids and basic url sanity.

=cut

sub edit_photos {
    my ( $dbh, $posts ) = @_;
    my %message;
    if ( !defined $dbh )                { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !exists $posts->{'host_id'} )  { return { 'ERROR' => $MSG_PROG_ERR }; }
    if ( !exists $posts->{'photo_id'} ) { return { 'ERROR' => $MSG_PROG_ERR }; }

    if (
        !exists $posts->{'photo_url'}
        || $posts->{'photo_url'} =~
        m/[^\w\-\:\/\.]/x    #not perfect but ok for now
        || length( $posts->{'photo_url'} ) < 1
        || length( $posts->{'photo_url'} ) > $URL_MAX_LENGTH
      )
    {

        return { 'ERROR' => $MSG_INPUT_ERR };
    }

    my $sth = $dbh->prepare('UPDATE photos SET host_id=?,url=? WHERE id=?');
    if (
        !$sth->execute(
            $posts->{'host_id'}, $posts->{'photo_url'},
            $posts->{'photo_id'}
        )
      )
    {
        return { 'ERROR' => $MSG_EDIT_ERR };
    }

    return { 'SUCCESS' => $MSG_EDIT_OK };
}

=pod

=head2 get_photos_info

Main individual record retrieval sub. 
 get_photos_info ( $dbh, $photos_id )

Returns the details in a hash.

=cut

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

=pod

=head2 get_photos_byhostid

Show all photos related to a given host

 get_photos_byhostid ( $dbh, $host_id )

Returns the details in a hash.

=cut

sub get_photos_byhostid {

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

=pod

=head2 upload_photos

upload a file onto the server then create a entry for the file
 upload_photos($dbh, $type, $upload_extension, $upload_dir, $website, $image_path, $POSTS);)


=cut

sub upload_photos {
    my %message;
    my $dbh              = shift;
    my $type             = shift;
    my $upload_extension = shift;
    my $upload_dir       = shift;
    my $website          = shift;
    my $image_path       = shift;
    my $posts            = shift;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }

    my $query = CGI->new();

    my $original_name = $query->param("$type$upload_extension");
    my ( $name, $path, $extension ) = fileparse( $original_name, '\..*' );

    # taints mode belts braces
    $posts->{'host_id'} =~ s/\D//gx;
    $upload_extension   =~ s/\W//gx;
    $extension          =~ s/[^a-zA-Z]//gx;

    # FIXME: no, apparently still tainted
    # need to match and then extract the matched var
    #

    my $fh = CGI::upload("$type$upload_extension");
    if ( defined $fh ) {

        my $md5 = Digest::MD5->new->addfile(*$fh)->hexdigest;

        my $host_id  = $posts->{'host_id'};
        my $filename = "$md5.$extension";

        # rewind after the md5 calculation
        seek $fh, 0, 0;

        open my $UPLOADFILE, '>', "$upload_dir/$filename" or croak $!;
        binmode $UPLOADFILE;

        # Copy a binary file to somewhere safe
        my $buffer;
        while ( my $bytesread = read $fh, $buffer, $READ_SIZE_CHARACTERS ) {
            print {$UPLOADFILE} $buffer;
        }
        close $UPLOADFILE or return { 'ERROR' => $MSG_FILECLOSE_ERR };

        $posts->{'photo_url'} = "$website/$image_path/$filename";

        # create a new entry?
        %message = %{ create_photos( $dbh, \%POSTS ) };
    }
    else {
        $message{'ERROR'} = $MSG_UPLOAD_ERR;
    }

    return \%message;
}

=pod

=head2 delete_photos

Delete a single photo.

 delete_photo( $dbh, $id );

Returns %hashref of either SUCCESS=> message or ERROR=> message

Checks for missing database handle and id.

=cut

sub delete_photos {
    my ( $dbh, $id ) = @_;

    if ( !defined $dbh ) { return { 'ERROR' => $MSG_DBH_ERR }; }
    if ( !defined $id )  { return { 'ERROR' => $MSG_PROG_ERR }; }

    my $sth = $dbh->prepare('DELETE FROM photos WHERE id=?');
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
