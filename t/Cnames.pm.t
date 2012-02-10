#!/usr/bin/perl
#
# Name: Cnames.pm.t
# Creator: auto
# Created: 2009-06-11

# Description: Auto generated basic uncustomised test file
#
# $Id: Cnames.pm.t 3523 2012-02-06 12:23:54Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 12:23:54 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3523 $
# $uid: sB2wYFK8PcmR6yWfnnD06wgF5ySSAy6F8I_0eWhUjSS7y $
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
# $result  = testing_namespace::internal_checkinput();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine internal_checkinput with 0 arguements'
# );

#
# $result  = testing_namespace::create_cnames();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine create_cnames with 0 arguements'
# );

#
# $result  = testing_namespace::create_cnames( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine create_cnames with 1 arguements'
# );

#
# $result  = testing_namespace::edit_cnames();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine edit_cnames with 0 arguements'
# );

#
# $result  = testing_namespace::edit_cnames( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine edit_cnames with 1 arguements'
# );

 Test::Pod::pod_file_ok( $testfile, 'Valid POD file' );

# pod_coverage_ok( 'Foo::Bar', 'Foo::Bar is covered' );

# $result=`perlcritic -4 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Cnames.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Cnames.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Cnames.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 4 without issue'
# );

# $result=`perlcritic -5 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Cnames.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Cnames.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Cnames.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 5 without issue'
# );

