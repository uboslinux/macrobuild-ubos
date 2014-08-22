# 
# Stage downloaded packages in a stage directory
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Stage;

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

    my $newPackages = $in->{'new-packages'};
    my $oldPackages = $in->{'old-packages'};
    my $staged      = {};

    my $destDir = $run->{settings}->replaceVariables( $self->{stagedir} );
    Macrobuild::Utils::ensureDirectories( $destDir );

    if( %$newPackages ) {
        while( my( $repoName, $repoData ) = each %$newPackages ) {
            while( my( $packageName, $fileName ) = each %$repoData ) {
                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                UBOS::Utils::myexec( "cp '$fileName' '$destDir/'" );

                $staged->{$packageName} = "$destDir/$localFileName";
                debug( "Staged:", $staged->{$packageName} );
            }
        }
    }
    if( defined( $oldPackages ) && %$oldPackages ) {
        while( my( $repoName, $repoData ) = each %$oldPackages ) {
            while( my( $packageName, $fileName ) = each %$repoData ) {
                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

				unless( -e "$destDir/$localFileName" ) {
					UBOS::Utils::myexec( "cp '$fileName' '$destDir/'" );

					$staged->{$packageName} = "$destDir/$localFileName";
					debug( "Staged again:", $staged->{$packageName} );
				}
            }
        }
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

