#!/usr/bin/perl
#
# Name: Memberships.pm.t
# Creator: auto
# Created: 2009-06-11

# Description: Auto generated basic uncustomised test file
#
# $Id: Memberships.pm.t 3523 2012-02-06 12:23:54Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 12:23:54 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3523 $
# $uid: IOu6ghkK1hmND5hN_NqjkY_oLW2S2ST5cNJGfWZSf5bxC $
#
 use strict;
 use warnings FATAL => 'all';

 use Test::More 'no_plan'; # replace with tests => n when ready
 use Test::GlassBox::Heavy qw(load_subs);
 use Test::Pod;
use Test::Pod::Coverage;
use Test::Pod::Coverage;


 ###############################################
 #                    config                   #
 ###############################################
 my $testfile=$0;
 $testfile=~ s/\.t$//;

 # load_subs( $testfile, 'testing_namespace' );
 ###############################################
 #                    tests                    #
 ###############################################

my $result1   = `/usr/bin/perl -c -T $testfile 2>&1`;
chomp $result1;
my $expected1 = "$testfile syntax OK";
is( $result1,
 $expected1,
 'Script passes a basic perl -c -T'
);

#
# $result  = testing_namespace::create_memberships();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine create_memberships with 0 arguements'
# );

#
# $result  = testing_namespace::create_memberships( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine create_memberships with 1 arguements'
# );

#
# $result  = testing_namespace::internal_checkinput();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine internal_checkinput with 0 arguements'
# );

#
# $result  = testing_namespace::get_memberships_info();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine get_memberships_info with 0 arguements'
# );

#
# $result  = testing_namespace::get_memberships_info( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine get_memberships_info with 1 arguements'
# );

#
# $result  = testing_namespace::count_memberships();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine count_memberships with 0 arguements'
# );

#
# $result  = testing_namespace::count_memberships( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine count_memberships with 1 arguements'
# );

#
# $result  = testing_namespace::edit_memberships();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine edit_memberships with 0 arguements'
# );

#
# $result  = testing_namespace::edit_memberships( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine edit_memberships with 1 arguements'
# );

 Test::Pod::pod_file_ok( $testfile, 'Valid POD file' );

# pod_coverage_ok( 'Foo::Bar', 'Foo::Bar is covered' );

# $result=`perlcritic -4 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Memberships.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Memberships.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Memberships.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 4 without issue'
# );

# $result=`perlcritic -5 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Memberships.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Memberships.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Memberships.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 5 without issue'
# );

