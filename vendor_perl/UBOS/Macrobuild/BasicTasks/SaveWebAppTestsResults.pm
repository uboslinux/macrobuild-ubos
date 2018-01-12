#!/usr/bin/perl
#
# Store the results of the web app tests execution.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults;

use base qw( Macrobuild::Task );
use fields qw( testLogsDir );

use Macrobuild::Task;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $testLogsDir = $self->getPropertyOrDefault( 'testLogsDir', undef );

    if( defined( $testLogsDir )) {
        unless( -d $testLogsDir ) {
            UBOS::Utils::mkdir( $testLogsDir );
        }
        my $testsSequence = $in->{'tests-sequence'};
        my $testsPassed   = $in->{'tests-passed'};
        my $testsFailed   = $in->{'tests-failed'};

        for( my $i=0 ; $i < @$testsSequence ; ++$i ) {
            my $testName = $testsSequence->[$i];
            my $content  = $testsPassed->{$testName};
            if( !defined( $content ) || $content =~ m!^\s*$! ) {
                $content = $testsFailed->{$testName};
            }
            $testName =~ s!/!_!g;
            if( $content && $content !~ m!\n\s*$! ) {
                $content .= "\n";
            }
            UBOS::Utils::saveFile( sprintf( "%s/%03d-%s.log", $testLogsDir, $i, $testName ), $content );
        }
        if( @$testsSequence ) {
            return SUCCESS;
        } else {
            return DONE_NOTHING;
        }
    }

    return DONE_NOTHING;
}

1;

