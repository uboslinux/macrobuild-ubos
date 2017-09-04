#
# Stage downloaded packages in a stage directory
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Stage;

use base qw( Macrobuild::Task );
use fields qw( stagedir );

use Macrobuild::Utils;
use UBOS::Logging;

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
    my $staged      = {}; # Map<packageName,file[]>: Value is an array, so it is symmetric to Unstage,
                          # which might unstage several package versions at the same time

    my $destDir = $run->{settings}->replaceVariables( $self->{stagedir} );

    Macrobuild::Utils::ensureDirectories( $destDir );

    if( %$newPackages ) {
        foreach my $uXConfigName ( sort keys %$newPackages ) {
            my $uXConfigData = $newPackages->{$uXConfigName};

            foreach my $packageName ( sort keys %$uXConfigData ) {
                my $fileName = $uXConfigData->{$packageName};

                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                UBOS::Utils::myexec( "cp '$fileName' '$destDir/'" );
                if( -e "$fileName.sig" ) {
                    UBOS::Utils::myexec( "cp '$fileName.sig' '$destDir/'" );
                }

                $staged->{$packageName} = "$destDir/$localFileName";
                trace( "Staged:", $staged->{$packageName} );
            }
        }
    }
    if( defined( $oldPackages ) && %$oldPackages ) {
        foreach my $repoName ( sort keys %$oldPackages ) {
            my $repoData = $oldPackages->{$repoName};

            foreach my $packageName ( sort keys %$repoData ) {
                my $fileName = $repoData->{$packageName};

                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                unless( -e "$destDir/$localFileName" ) {
                    UBOS::Utils::myexec( "cp '$fileName' '$destDir/'" );
                    if( -e "$fileName.sig" ) {
                        UBOS::Utils::myexec( "cp '$fileName.sig' '$destDir/'" );
                    }

                    $staged->{$packageName} = "$destDir/$localFileName";
                    trace( "Staged again:", $staged->{$packageName} );
                }
            }
        }
    }

    my $ret = 1;
    if( %$staged ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            { 'staged-packages' => $staged },
            $ret );

    return $ret;
}

1;

