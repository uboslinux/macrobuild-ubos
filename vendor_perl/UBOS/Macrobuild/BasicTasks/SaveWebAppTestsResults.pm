# 
# Store the results of the build.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults;

use base qw( Macrobuild::Task );
use fields qw( fields );

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self ); # ignore input

    my $testLogsDir = $run->getVariable( 'testLogsDir' );
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
    }

    $run->taskEnded( $self, {}, 0 );

    return 0;
}

1;

