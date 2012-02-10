#!/usr/bin/perl
#
# Name: Interfaces.pm.t
# Creator: auto
# Created: 2009-06-11

# Description: Auto generated basic uncustomised test file
#
# $Id: Interfaces.pm.t 3523 2012-02-06 12:23:54Z guy $
# $LastChangedBy: guy $
# $LastChangedDate: 2012-02-06 12:23:54 +0000 (Mon, 06 Feb 2012) $
# $LastChangedRevision: 3523 $
# $uid: dPbFgsCgBIjpRP8VAMZN_X1nJXnuph57PuRvJjxyQwkXL $
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
# $result  = testing_namespace::get_interfaces_info();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine get_interfaces_info with 0 arguements'
# );

#
# $result  = testing_namespace::get_interfaces_info( fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine get_interfaces_info with 1 arguements'
# );

#
# $result  = testing_namespace::get_interfaces_info( fooarg fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine get_interfaces_info with 2 arguements'
# );

#
# $result  = testing_namespace::get_interfaces_info( fooarg fooarg fooarg);
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine get_interfaces_info with 3 arguements'
# );

#
# $result  = testing_namespace::edit_interfaces();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine edit_interfaces with 0 arguements'
# );

#
# $result  = testing_namespace::create_interfaces();
# $exected = "";
# is( $result,
# $expected,
# 'Testing the subroutine create_interfaces with 0 arguements'
# );

 Test::Pod::pod_file_ok( $testfile, 'Valid POD file' );

# pod_coverage_ok( 'Foo::Bar', 'Foo::Bar is covered' );

# $result=`perlcritic -4 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Interfaces.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Interfaces.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Interfaces.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 4 without issue'
# );

# $result=`perlcritic -5 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Interfaces.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Interfaces.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory/Interfaces.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 5 without issue'
# );

