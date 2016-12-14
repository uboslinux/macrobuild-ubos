# 
# Remove one or more packages fetched from Arch and marked as such.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages;

use base qw( Macrobuild::Task );
use fields qw( sourcedir );

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

    my $sourceDir = $run->replaceVariables( $self->{sourcedir} );
    my $arch      = $run->getVariable( 'arch' );

    my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );

    my $removedPackages = {};

    my $ok = 1;
    foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$repoName}; 

        my $removePackages = $upConfig->removePackages;
        unless( $removePackages ) {
            next;
        }

        foreach my $removePackage ( @$removePackages ) {
            my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $removePackage, $sourceDir, $arch );

            UBOS::Utils::deleteFile( @files );
            $removedPackages->{$removePackage} = \@files;
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

    return $ret;
}

1;
