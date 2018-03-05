#!/usr/bin/perl
#
# Print the input of this task
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Report;

use base qw( Macrobuild::Task );
use fields qw( maxLevels );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in        = $run->getInput();
    my $maxLevels = $self->getPropertyOrDefault( 'maxLevels', ~0 );

    print "REPORT:\n";
    if( $in && keys %$in ) {
        _report( 0, $in, $maxLevels );

    } else {
        print "No data.\n";
    }
    return SUCCESS();
}

##
# Recursivsly invoked
# $level: the current level
# $data: the data to emit
# $max: the maximum level to report on
sub _report {
    my $level = shift;
    my $data  = shift;
    my $max   = shift;

    if( $level < $max ) {
        my $indent  = '  ' x $level;
        my $indent2 = '  ' x ( $level + 1 );

        my $type = ref( $data );
        if( 'ARRAY' eq $type ) {
            print "[\n";
            foreach my $value ( @$data ) {
                print $indent2;
                _report( $level+1, $value, $max );
            }
            print $indent . "]\n";
        } elsif( 'HASH' eq $type ) {
            print "{\n";
            foreach my $key ( sort keys %$data ) {
                print $indent2 . $key . ': ';
                _report( $level+1, $data->{$key}, $max );
            }
            print $indent . "}\n";
        } elsif( !$type ) {
            print $data . "\n";
        } else {
            print "<unprintable type $type>\n";
        }
    }
}

1;

