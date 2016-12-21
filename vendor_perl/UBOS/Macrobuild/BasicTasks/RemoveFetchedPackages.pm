# 
# Remove one or more packages fetched from Arch and marked as such.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages;

use base qw( Macrobuild::Task );
use fields qw( upconfigs downloaddir );

use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $downloadDir = $run->replaceVariables( $self->{downloaddir} );
    my $arch        = $run->getVariable( 'arch' );

    my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );

    my $removedPackages = {};

    my $ok = 1;
    foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$repoName}; 

        my $removePackages = $upConfig->removePackages;
        unless( $removePackages ) {
            next;
        }

        foreach my $removePackage ( keys %$removePackages ) {
            my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $removePackage, $downloadDir, $arch );

            UBOS::Utils::deleteFile( @files );
            $removedPackages->{$repoName}->{$removePackage} = \@files;
        }
    }

    my $ret = 1;
    if( !$ok ) {
        $ret = -1;

    } elsif( keys %$removedPackages ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            {
                'removed-packages' => $removedPackages
            },
            $ret );
    # Map<repoName,Map<packageName,file[]>>

    return $ret;
}

1;
