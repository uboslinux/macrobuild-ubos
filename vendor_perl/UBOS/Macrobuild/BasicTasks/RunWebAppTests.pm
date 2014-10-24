# 
# Run webapptests in the usconfigs.
# This does NOT pull sources for the tests; it is assumed that they are current
# in the right directories.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RunWebAppTests;

use base qw( Macrobuild::Task );
use fields qw( usconfigs sourcedir );

use Macrobuild::Utils;
use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $scaffold    = $run->getSettings->getVariable( 'scaffold' );
    my $testplan    = $run->getSettings->getVariable( 'testplan' );
    my $testVerbose = $run->getSettings->getVariable( 'testverbose' );

    my $testCmd  = 'webapptest run';

    if( defined( $scaffold )) {
        $testCmd .= ' --scaffold ' . $scaffold;
    }
    if( defined( $testplan )) {
        $testCmd .= ' --testplan ' . $testplan;
    }
    if( defined( $testVerbose )) {
        $testCmd .= " $testVerbose";
    }

    my $testsSequence = [];
    my $testsPassed   = {};
    my $testsFailed   = {};

    my $usConfigs = $self->{usconfigs}->configs( $run->{settings} );
    foreach my $repoName ( sort keys %$usConfigs ) { # make predictable sequence
        my $usConfig = $usConfigs->{$repoName}; 

        my $name = $usConfig->name;
        debug( "Now processing upstream source config file", $name );

        my $webapptests = $usConfig->webapptests;
        if( defined( $webapptests ) && @$webapptests ) {
            my $sourceSourceDir = $run->replaceVariables( $self->{sourcedir} ) . "/$name";
	        if( -d $sourceSourceDir ) {
                foreach my $test ( @$webapptests ) {
                    my $testDir;
                    my $file;
                    if( $test =~ m!^(.*)/([^/]+)$! ) {
                        $testDir = $sourceSourceDir . '/' . $1;
                        $file    = $2;
                    } else {
                        $testDir = $sourceSourceDir;
                        $file    = $test;
                    }

                    info( "Running test $testDir/$file" );

                    push @$testsSequence, "$name::$test";

                    my $out;
                    if( UBOS::Utils::myexec( "cd '$testDir'; $testCmd " . $file . " 2>&1", undef, \$out )) {
                        $out =~ s!\s+$!!;
                        error( 'Test', $test, 'failed:', $out );
                        $testsFailed->{"$name::$test"} = $out;
                    } else {
                        $out =~ s!\s+$!!;
                        $testsPassed->{"$name::$test"} = 'Passed.';
                    }
                }
            } else {
                my $msg = "Cannot run webapptests defined in $name. Directory $sourceSourceDir not found.";
                
                error( $msg );
                map { $testsFailed->{"$name :: $_"} = $msg; } @$webapptests;
            }
		}
    }

    $run->taskEnded( $self, {
            'tests-sequence' => $testsSequence,
            'tests-passed'   => $testsPassed,
            'tests-failed'   => $testsFailed
    } );
    
    if( %$testsFailed ) {
        return -1;
    } elsif( %$testsPassed ) {
        return 0;
    } else {
        return 1;
    }
}


1;

