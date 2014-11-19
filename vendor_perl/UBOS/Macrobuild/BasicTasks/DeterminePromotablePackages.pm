# 
# Determine which packages can be promoted from one repository in
# one channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages;

use base qw( Macrobuild::Task );
use fields qw( upconfigs usconfigs fromRepository toRepository );

use File::Spec;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $arch      = $run->getVariable( 'arch' );
    my $toChannel = $run->getVariable( 'toChannel' );
    unless( $arch ) {
        error( 'Variable not set: arch' );
        return -1;
    }
    unless( $toChannel ) {
        error( 'Variable not set: toChannel' );
        return -1;
    }

    $run->taskStarting( $self ); # input ignored

    my $fromRepository = $run->replaceVariables( $self->{fromRepository} );
    my $toRepository   = $run->replaceVariables( $self->{toRepository} );

    my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );
    my $usConfigs = $self->{usconfigs}->configs( $run->{settings} );
    
    my $newPackages = {};
    my $oldPackages = {};
    
    foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$repoName}; 

        foreach my $packageName ( sort keys %{$upConfig->packages} ) { # make predictable sequence
            my $packageInfo = $upConfig->packages->{$packageName};

            my @candidatePackages = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $fromRepository, $arch );
            my $toPromote;
            if( exists( $packageInfo->{$toChannel}->{version} )) {
                if( exists( $packageInfo->{$toChannel}->{release} )) {
                    $toPromote = UBOS::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$toChannel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $toChannel );
                }
            } else {
                $toPromote = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
            }
            if( defined( $toPromote )) {
                if( -e "$toRepository/$toPromote" ) {
                    $oldPackages->{$repoName}->{$packageName} = "$fromRepository/$toPromote";
                } else {
                    $newPackages->{$repoName}->{$packageName} = "$fromRepository/$toPromote";
                }
            }
        }
    }

    # usconfig uses very similar code to upconfig
    foreach my $usConfig ( values %$usConfigs ) {
        my $repoName = $usConfig->name;

        foreach my $packageName ( sort keys %{$usConfig->packages} ) {
            my $packageInfo = $usConfig->packages->{$packageName};

            my @candidatePackages = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $fromRepository, $arch );
            my $toPromote;
            if( exists( $packageInfo->{$toChannel}->{version} )) {
                if( exists( $packageInfo->{$toChannel}->{release} )) {
                    $toPromote = UBOS::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$toChannel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $toChannel );
                }
            } else {
                $toPromote = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
            }
            if( defined( $toPromote )) {
                if( -e "$toRepository/$toPromote" ) {
                    $oldPackages->{$repoName}->{$packageName} = "$fromRepository/$toPromote";
                } else {
                    $newPackages->{$repoName}->{$packageName} = "$fromRepository/$toPromote";
                }
            }
        }
    }

    my $ret = 1;
    if( keys %$newPackages ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            {
                'new-packages' => $newPackages,
                'old-packages' => $oldPackages
            },
            $ret );

    return $ret;
}

1;

