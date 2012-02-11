#!perl
#
# $Id: coding-standard.t 3539 2012-02-10 16:01:31Z guy $
# $LastChangedDate: 2012-02-10 16:01:31 +0000 (Fri, 10 Feb 2012) $
# $LastChangedBy: guy $
# $Revision: 3539 $
#

=pod

=head1 NAME

test-tests.t

=head1 SYNOPSIS

prove test-tests.t

=head1 DESCRIPTION

Test the test scripts for basic sanity

=head1 METHODS

none

=cut

use strict;
use warnings;
use diagnostics;
use feature ':5.11';

use Readonly;
use Test::PerlTidy;
use Perl::Critic qw(critique);

=head1 PLAN

Currently the files to test are manually specified

=cut

my %testfiles = (

    'coding-standard.t' => 'test',

    '../admin'               => 'script',
    '../bashrc'              => 'script',
    '../cnames'              => 'script',
    '../contacts'            => 'script',
    '../contracts'           => 'script',
    '../edithost'            => 'script',
    '../evil-frodo'          => 'script',
    '../frodo'               => 'script',
    '../hostgroups'          => 'script',
    '../hosts'               => 'script',
    '../index'               => 'script',
    '../interfaces'          => 'script',
    '../introlemembers'      => 'script',
    '../introles'            => 'script',
    '../invoices'            => 'script',
    '../locations'           => 'script',
    '../manufacturers'       => 'script',
    '../memberships'         => 'script',
    '../models'              => 'script',
    '../photos'              => 'script',
    '../problems_interfaces' => 'script',
    '../servicegroups'       => 'script',
    '../sshkeys'             => 'script',
    '../status'              => 'script',
    '../suppliers'           => 'script',
    '../ups'                 => 'script',
    '../viewhost'            => 'script',

    '../lib/modules/Inventory.pm'                => 'module',
    '../lib/modules/Inventory/Cnames.pm'         => 'module',
    '../lib/modules/Inventory/Contacts.pm'       => 'module',
    '../lib/modules/Inventory/Contracts.pm'      => 'module',
    '../lib/modules/Inventory/Edithost.pm'       => 'module',
    '../lib/modules/Inventory/Frodos.pm'         => 'module',
    '../lib/modules/Inventory/Hostgroups.pm'     => 'module',
    '../lib/modules/Inventory/Hosts.pm'          => 'module',
    '../lib/modules/Inventory/Interfaces.pm'     => 'module',
    '../lib/modules/Inventory/Introlemembers.pm' => 'module',
    '../lib/modules/Inventory/Introles.pm'       => 'module',
    '../lib/modules/Inventory/Invoices.pm'       => 'module',
    '../lib/modules/Inventory/Locations.pm'      => 'module',
    '../lib/modules/Inventory/Manufacturers.pm'  => 'module',
    '../lib/modules/Inventory/Memberships.pm'    => 'module',
    '../lib/modules/Inventory/Models.pm'         => 'module',
    '../lib/modules/Inventory/Op2devices.pm'     => 'module',
    '../lib/modules/Inventory/Photos.pm'         => 'module',
    '../lib/modules/Inventory/Servicegroups.pm'  => 'module',
    '../lib/modules/Inventory/Sshkeys.pm'        => 'module',
    '../lib/modules/Inventory/Status.pm'         => 'module',
    '../lib/modules/Inventory/Suppliers.pm'      => 'module',
    '../lib/modules/Inventory/Ups.pm'            => 'module',

);
use Test::More tests => 204;
use Test::Pod 1.00;

=head1 TESTS

* Test the pod is correct
* Test the script passes perlcritic -3
* Test the script passes perltidy
* Check for development statements left in code

=cut

foreach my $file ( keys %testfiles ) {

=pod 

=head2 Basic Correctness of Perl

does the code pass perl -c -T

=cut

    #my $result1   = `/usr/bin/perl -c -T $file 2>&1`;
    #chomp $result1;
    #my $expected1 = "$file syntax OK";
    #is( $result1, $expected1, "$file passes a basic perl -c -T" );

=head2 POD format

test the pod is correct
    
=cut

    pod_file_ok( $file, "Valid POD file for $file" );

=pod

=head2 Perlcritic

Test code passes to level 3. This tests passes the laxer levels as well to
give beter immediate feedback on the level of failure.

=cut

    foreach my $level (qw(5 4)) {
        my @violations =
          Perl::Critic::critique( { -severity => $level }, $file );
        is( scalar @violations, 0,
            "Pass Perlcritic at level $level for $file" );
    }

=pod

=head2 Perltidy

Check the code is tidy according to Perltidy

=cut

    is( Test::PerlTidy::is_file_tidy($file), 1,
        "Pass PerlTidy test for $file" );

=pod

=head2 Leftover development code

Check for leftover potential trap and print development statements
      
=cut

    #    is( bad_statements($file), 0,
    #        "Possible development statements left in code for $file" );

}

sub bad_statements {

    # Here we look for what might be development comments (and possibly code)
    # left over from the creation or modification of a script and which
    # shouldn't make it out to our production code.
    #
    my $filename = shift;
    my $matches  = 0;

    open my $FILE, '<', $filename or Carp::croak "Cannot open $filename: $!";
    my @lines = <$FILE>;
    close $FILE or Carp::croak "Cannot close $filename: $!";

    foreach (@lines) {

        # First letter is boxed so that this script can test itself
        if ( m/[f]ixme/ix or m/[t]odo/ix ) {
            Carp::carp "\nSUSPECT: '$_'\n\n";
            $matches++;
        }

        # Log::Log4perl makes things a little more complciated
        # [^>] = do not catch $logger->debug
        # [^\$] = do not catch Log::Log4perl->easy_init($DEBUG)
        #
        if (m/[^\$>][d]ebug/ix) {
            chomp;
            Carp::carp "\nSUSPECT: '$_'\n\n";
            $matches++;
        }
    }

    return $matches;
}

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

The University of Oxford disclaims all copyright interest in the program
`Inventory' written by Guy Edwards as agreed by Dr. Stuart Lee, Director of
Oxford University Computer Services.

Oliver Gorwits, who in 2008 contributed sections of the hostgroups programming
also disclaims all copyright interest in the program.
