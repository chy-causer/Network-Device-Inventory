#!/usr/bin/perl
#
# Name: Cnames.pm.t
# Created: 2012-02-27
# Author: Guy Edwards
# Description: Tests specific to Cnames.pm

use strict;
use warnings FATAL => 'all';

###############################################
#                    config                   #
###############################################

use Test::More 'no_plan'; # replace with tests => n when ready

###############################################
#                    tests                    #
###############################################

is( $result1,
 $expected1,
 'Script passes a basic perl -c -T'
);

# host_id needs to be a known value of a live host
#
my %testentry = (
     host_id   => '191',
     shortname => 'inventorytestcreate-123',
     dnsname   => 'inventorytestcreate',
);

my %testentry2 = (
     host_id   => '162',
     shortname => 'inventorytestcreate-234',
     dnsname   => 'inventorytestcreate',
);


my %testedit = (
   cname_id => ,
   host_id => '191',
   shortname => 'inventorytestedit-123',
   dnsname => 'inventorytestedit',
);


# 1. Test creation of a record
Inventory::Cnames::create_cnames( $dbh, %testentry );
my @results = @{ Inventory::Cnames::get_cnames_info( $dbh, $testentry{host_id} ) };

is( $results[0]{shortname}, $testentry{shortname}, 
                    'create_cnames shortname creation ok' );
is( $results[0]{host_id},   $testentry{host_id},   
                    'create_cnames host_id creation ok' );
is( $results[0]{dnsname}, $testentry{dnsname}, 
                    'create_cnames dnsname creation ok' );

# 2. Test editing that record
Inventory::Cnames::edit_cnames ($dbh, %testedit);
my @edit_results = @{ Inventory::Cnames::get_cnames_info( $dbh, $testentry{host_id} ) };

is( $edit_results[0]{shortname}, $testedit{shortname}, 
                    'edit_cnames shortname edit ok' );
is( $edit_results[0]{host_id},   $testedit{host_id},   
                    'edit_cnames host_id edit ok' );
is( $edit_results[0]{dnsname}, $testedit{dnsname}, 
                    'edit_cnames dnsname edit ok' );

# 3. Test deleting that record
Inventory::cnames::delete_cname( $dbh, $cname_id );
my @edit_results = @{ Inventory::Cnames::get_cnames_info( $dbh, $testentry{host_id} ) };
is(scalar @edit_results, 0, 'delete_cname entry deletion ok')

# 4. Test creation via shortname route 
Inventory::Cnames::create_shortcname ( $dbh, %testentry );
my @short_results = @{ Inventory::Cnames::get_cnames_info( $dbh, $testentry{host_id} ); };

is( $short_results[0]{shortname}, $testentry{shortname}, 
                    'create_shortcnames shortname creation ok' );
is( $short_results[0]{host_id},   $testentry{host_id},   
                    'create_shortcnames host_id creation ok' );
is( $short_results[0]{dnsname}, $testentry{dnsname}, 
                    'create_shortcnames dnsname creation ok' );

# 5. test editing via shortname route
Inventory::Cnames::edit_shortcnames($dbh, %testedit);
my @shortedit_results = @{ Inventory::Cnames::get_cnames_info( $dbh, $testentry{host_id} ) };

is( $shortedit_results[0]{shortname}, $testedit{shortname},
                    'edit_shortcnames shortname edit ok' );
is( $shortedit_results[0]{host_id},   $testedit{host_id},  
                    'edit_shortcnames host_id edit ok' );
is( $shortedit_results[0]{dnsname}, $testedit{dnsname},
                    'edit_shortcnames dnsname edit ok' );
Inventory::Cnames::get_cnames_info( $dbh, $host_id );

Inventory::cnames::delete_cname( $dbh, $cname_id );
my @edit_results = @{ Inventory::Cnames::get_cnames_info( $dbh, $testentry{host_id} ) };
is(scalar @edit_results, 0, 'delete_cname operation ok')


# 6. Test listing all cnames works
my @all_results = get_cnames_info( $dbh );
is(scalar @all_results, > 1, 'Listed all results ok');


