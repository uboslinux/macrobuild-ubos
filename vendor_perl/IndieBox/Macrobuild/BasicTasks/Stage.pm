# 
# Stage downloaded packages in a stage directory
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::Stage;

use base qw( Macrobuild::Task );
use fields qw( stagedir );

use Macrobuild::Logging;
use Macrobuild::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    unless( exists( $in->{'new-packages'} )) {
        error( "No new-packages given in input" );
        return -1;
    }

    my $downloaded = $in->{'new-packages'};
    my $staged     = {};

    if( %$downloaded ) {
        my $destDir = $run->{settings}->replaceVariables( $self->{stagedir} );
        Macrobuild::Utils::ensureDirectories( $destDir );

        while( my( $repoName, $repoData ) = each %$downloaded ) {
            while( my( $packageName, $fileName ) = each %$repoData ) {
                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                IndieBox::Utils::myexec( "cp '$fileName' '$destDir/'" );

                $staged->{$packageName} = "$destDir/$localFileName";
            }
        }
    } else {
        info( "Running " . $self->name . ": No packages to downloaded, nothing to do" );
    }

    $run->taskEnded( $self, {
            'staged-packages' => $staged
    } );
    if( %$staged ) {
        return 0;
    } else {
        return 1;
    }
}

1;

