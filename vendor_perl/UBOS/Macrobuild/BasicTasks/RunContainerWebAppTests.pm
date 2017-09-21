#
# Run webapptests in ONE usconfig in a container.
# This does NOT pull sources for the tests; it is assumed that they are current
# in the right directories.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RunContainerWebAppTests;

use base qw( Macrobuild::Task );
use fields qw( usconfig sourcedir config scaffold directory );

use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $testCmd  = 'webapptest run';

    my $config = $self->getPropertyOrDefault( 'config', undef );
    if( defined( $config )) {
        $testCmd .= " --config '$config'";
    }

    my $scaffold  = $self->getProperty( 'scaffold' );
    my $directory = $self->getPropertyOrDefault( 'directory', undef );
    if( $directory ) {
        $testCmd .= " --scaffold 'container:directory=$directory'";
    }

    my $testsSequence = [];
    my $testsPassed   = {};
    my $testsFailed   = {};

    my $usConfig = $self->{usconfig};

    my $name = $usConfig->name;
    trace( "Now processing upstream source config file", $name );

    my $webapptests = $usConfig->webapptests;
    my $sourceDir   = $self->getProperty( 'sourcedir' );
    if( defined( $webapptests ) && keys %$webapptests ) {
        my $sourceSourceDir = "$sourceDir/$name";
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

    $run->setOutput( {
            'tests-sequence' => $testsSequence,
            'tests-passed'   => $testsPassed,
            'tests-failed'   => $testsFailed
    } );

    if( %$testsFailed ) {
        return FAIL;
    } elsif( %$testsPassed ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

