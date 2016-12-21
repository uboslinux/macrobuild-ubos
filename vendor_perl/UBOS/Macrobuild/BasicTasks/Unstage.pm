# 
# Unstage removed packages from the stage directory
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Unstage;

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

    my $unstaged = {};
    if( exists( $in->{'removed-packages'} )) {

        my $removedPackages = $in->{'removed-packages'};

        my $destDir = $run->{settings}->replaceVariables( $self->{stagedir} );

        Macrobuild::Utils::ensureDirectories( $destDir );

        if( %$removedPackages ) {
            foreach my $uXConfigName ( sort keys %$removedPackages ) {
                my $uXConfigData = $removedPackages->{$uXConfigName};

                foreach my $packageName ( sort keys %$uXConfigData ) {
                    $unstaged->{$packageName} = [];

                    foreach my $fileName ( @{$uXConfigData->{$packageName}} ) {

                        my $localFileName = $fileName;
                        $localFileName =~ s!.*/!!;

                        UBOS::Utils::myexec( "rm '$destDir/$localFileName'" );
                        if( -e "$destDir/$localFileName.sig" ) {
                            UBOS::Utils::myexec( "rm '$destDir/$localFileName'" );
                        }

                        push @{$unstaged->{$packageName}}, "$destDir/$localFileName";
                    }
                    debug( "Unstaged:", $packageName, @{$unstaged->{$packageName}} );
                }
            }
        }
    }

    my $ret = 1;
    if( %$unstaged ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            { 'unstaged-packages' => $unstaged },
            $ret );

    return $ret;
}

1;

