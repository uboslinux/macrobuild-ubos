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

    my $scaffold    = $run->getVariable( 'scaffold' );    # ok if not exists
    my $testplan    = $run->getVariable( 'testplan' );    # ok if not exists
    my $testVerbose = $run->getVariable( 'testverbose' ); # ok if not exists

    my $testCmd  = 'webapptest run';

    if( defined( $scaffold )) {
        $testCmd .= ' --scaffold ' . $scaffold;
    }

    if( defined( $testplan )) {
        if( ref( $testplan ) eq 'ARRAY' ) {
            if( @$testplan ) {
                $testCmd .= ' ' . join( ' ', map { '--testplan ' . $_ } @$testplan );
            }
        } else {
            $testCmd .= ' --testplan ' . $testplan;
        }
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
                    if( UBOS::Utils::myexec( "cd '$testDir'; $testCmd " . $file, undef, \$out, \$out )) {
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

    my $ret = 1;
    if( %$testsFailed ) {
        $ret = -1;
    } elsif( %$testsPassed ) {
        $ret = 0;
    }
    
    $run->taskEnded(
            $self,
            {
                'tests-sequence' => $testsSequence,
                'tests-passed'   => $testsPassed,
                'tests-failed'   => $testsFailed
            },
            $ret );

    return $ret;
}

1;

