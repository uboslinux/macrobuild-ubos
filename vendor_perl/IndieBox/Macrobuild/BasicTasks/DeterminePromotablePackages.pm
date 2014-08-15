# 
# Determine which packages can be promoted from one repository in
# one channel to another.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::DeterminePromotablePackages;

use base qw( Macrobuild::Task );
use fields qw( upconfigs usconfigs fromRepository toRepository );

use File::Spec;
use IndieBox::Macrobuild::PackageUtils;
use IndieBox::Utils;
use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $toChannel      = $run->getSettings->getVariable( 'toChannel' );
    my $fromRepository = $run->replaceVariables( $self->{fromRepository} );
    my $toRepository   = $run->replaceVariables( $self->{toRepository} );

    my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );
    my $usConfigs = $self->{usconfigs}->configs( $run->{settings} );
    my $arch      = $run->getVariable( 'arch' );
    
    my $newPackages = {};
    my $oldPackages = {};
    
    while( my( $repoName, $upConfig ) = each %$upConfigs ) {
        while( my( $packageName, $packageInfo ) = each %{$upConfig->packages} ) {

            my @candidatePackages = IndieBox::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $fromRepository, $arch );
            my $toPromote;
            if( exists( $packageInfo->{$toChannel}->{version} )) {
                if( exists( $packageInfo->{$toChannel}->{release} )) {
                    $toPromote = IndieBox::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$toChannel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $toChannel );
                }
            } else {
                $toPromote = IndieBox::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
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
        while( my( $packageName, $packageInfo ) = each %{$usConfig->packages} ) {

            my @candidatePackages = IndieBox::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $fromRepository, $arch );
            my $toPromote;
            if( exists( $packageInfo->{$toChannel}->{version} )) {
                if( exists( $packageInfo->{$toChannel}->{release} )) {
                    $toPromote = IndieBox::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$toChannel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $toChannel );
                }
            } else {
                $toPromote = IndieBox::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
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

    $run->taskEnded( $self, {
            'new-packages' => $newPackages,
            'old-packages' => $oldPackages
    } );

    if( keys %$newPackages ) {
        return 0;
    } else {
        return 1;
    }
}

1;

