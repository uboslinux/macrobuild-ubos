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

    unless( exists( $in->{'removed-packages'} )) {
        error( "No removed-packages given in input" );
        return -1;
    }

    my $removedPackages = $in->{'removed-packages'};
    my $unstaged        = {};

    my $destDir = $run->{settings}->replaceVariables( $self->{stagedir} );

    Macrobuild::Utils::ensureDirectories( $destDir );

    if( %$removedPackages ) {
        foreach my $repoName ( sort keys %$removedPackages ) {
            my $repoData = $removedPackages->{$repoName};

            foreach my $packageName ( sort keys %$repoData ) {
                my $fileName = $repoData->{$packageName};

                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                UBOS::Utils::myexec( "rm '$destDir/$localFileName'" );
                if( -e "$destDir/$localFileName.sig" ) {
                    UBOS::Utils::myexec( "rm '$destDir/$localFileName'" );
                }

                $unstaged->{$packageName} = "$destDir/$localFileName";
                debug( "Unstaged:", $unstaged->{$packageName} );
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

