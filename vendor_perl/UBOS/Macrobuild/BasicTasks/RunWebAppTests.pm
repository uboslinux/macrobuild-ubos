#
# Run webapptests in ONE usconfig.
# This does NOT pull sources for the tests; it is assumed that they are current
# in the right directories.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RunWebAppTests;

use base qw( Macrobuild::Task );
use fields qw( usconfig sourcedir config scaffold directory vmdktemplate);

use Macrobuild::Utils;
use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $testCmd  = 'webapptest run';

    my $config = $run->replaceVariables( $self->{config} );
    if( defined( $config )) {
        $testCmd .= " --config '$config'";
    }

    my $scaffold = $run->replaceVariables( $self->{scaffold} );

    my $directory = $run->replaceVariables( $self->{directory} );
    if( $directory && ( !$scaffold || 'container' eq $scaffold )) {
        $testCmd .= " --scaffold 'container:directory=$directory'";
    }

    my $vmdkTemplate = $run->replaceVariables( $self->{vmdktemplate} );
    if( $vmdkTemplate && ( !$scaffold || 'vbox' eq $scaffold )) {
        $testCmd .= " --scaffold 'vbox:vmdktemplate=$vmdkTemplate'";
    }

    my $testsSequence = [];
    my $testsPassed   = {};
    my $testsFailed   = {};

    my $usConfig = $self->{usconfig};

    my $name = $usConfig->name;
    trace( "Now processing upstream source config file", $name );

    my $webapptests = $usConfig->webapptests;
    if( defined( $webapptests ) && keys %$webapptests ) {
        my $sourceSourceDir = $run->replaceVariables( $self->{sourcedir} ) . "/$name";
        if( -d $sourceSourceDir ) {
            foreach my $test ( keys %$webapptests ) {
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

                push @$testsSequence, $name . '::' . $test;

                my $out;
                if( UBOS::Utils::myexec( "$testCmd '$testDir/$file'", undef, \$out, \$out )) {
                    $out =~ s!\s+$!!;
                    error( 'Test', $test, 'failed:', $out, ', command was:', "$testCmd '$testDir/$file'" );
                    $testsFailed->{$name . '::' . $test} = $out;
                } else {
                    $out =~ s!\s+$!!;
                    $testsPassed->{$name . '::' . $test} = 'Passed.';
                }
            }
        } else {
            my $msg = "Cannot run webapptests defined in $name. Directory $sourceSourceDir not found.";

            error( $msg );
            map { $testsFailed->{$name . '::' . $_} = $msg; } @$webapptests;
        }

        if( $self->{stopOnError} && %$testsFailed ) {
            error( "ERROR in last test and stopOnError is true. Stopping." );
            last;
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

