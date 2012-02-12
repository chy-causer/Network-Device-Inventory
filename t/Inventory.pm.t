#!/usr/bin/perl
#
# Name: Inventory.pm.t
# Creator: auto
# Created: 2009-06-11

# Description: Auto generated basic uncustomised test file
#
# $Id: Inventory.pm.t 2514 2009-06-12 08:44:01Z networks $
# $LastChangedBy: networks $
# $LastChangedDate: 2009-06-12 09:44:01 +0100 (Fri, 12 Jun 2009) $
# $LastChangedRevision: 2514 $
# $uid: MVpUJFk6eK92v3kUDfychr4CTg9bxC_uKO_y8VN_o2ACb $
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

 Test::Pod::pod_file_ok( $testfile, 'Valid POD file' );

# pod_coverage_ok( 'Foo::Bar', 'Foo::Bar is covered' );

# $result=`perlcritic -4 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 4 without issue'
# );

# $result=`perlcritic -5 /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory.pm`
# chomp /home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory.pm
# $exected = "/home/networks/subversion/networks/src/local/www/inventory/lib/modules/Inventory.pm source OK";
# is( $result,
# $expected,
# 'The script passes percritic level 5 without issue'
# );

