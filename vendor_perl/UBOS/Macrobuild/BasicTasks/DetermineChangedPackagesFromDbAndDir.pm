# 
# Determine which packages, of the ones we want, have new versions
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;

use base qw( Macrobuild::Task );
use fields qw( dir upconfigs );

use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $arch = $run->getVariable( 'arch' );
    unless( $arch ) {
        error( 'Variable not set: arch' );
        return -1;
    }

    my $in = $run->taskStarting( $self );

    my $packageDatabases = $in->{'all-package-databases'};
            # This one does not work:
            #     $in->{'updated-package-databases'};
            # because several repositories access the same upstream repository, and on the
            # second access, it says "not changed" although it might have in the first
            # access during the same build. As a result, some packages won't be updated.
    my $dir = $run->{settings}->replaceVariables( $self->{dir} );

    my $toDownload = {};
    if( %$packageDatabases ) {
        my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );
        foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
            my $upConfig = $upConfigs->{$repoName}; 

            debug( 'Determining changed packages in repo', $repoName );
            
            my $packageDatabase = $packageDatabases->{$repoName};
            unless( $packageDatabase ) {
                # wasn't updated, nothing to do
                next;
            }
            my $repoDir            = "$dir/$repoName";
            my $packagesInDatabase = $packageDatabase->containedPackages(); # returns name => filename

            # in case you were wondering, here's the filtering that says which packages we want
            foreach my $packageName ( sort keys %{$upConfig->packages} ) { # make predictable sequence
                my $packageInfo = $upConfig->packages->{$packageName};

                my $packageFileInPackageDatabase = $packagesInDatabase->{$packageName};
                debug( 'Considering package', $packageName, 'in updated package database version', $packageFileInPackageDatabase );
                
                if( $packageFileInPackageDatabase ) {
                    my @packageFileLocalCandidates = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $dir, $arch );
                    
                    my $bestLocalCandidate = undef;
                    if( @packageFileLocalCandidates ) {
                        # we have one or more versions
                        $bestLocalCandidate = UBOS::BasicTasks::PackageUtils::mostRecentPackageVersion( @packageFileLocalCandidates ); # most recent now at bottom
                    } else {
                        # nothing local
                    }
                    if( !$bestLocalCandidate || $bestLocalCandidate ne $packageFileInPackageDatabase ) {
                        my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                        $toDownload->{$repoName}->{$packageName} = $url;
                    }
                } else {
                    warning( 'Failed to find package file for package', $packageName, 'in database for repo', $repoName );
                }
            }
        }
    }

    my $ret = 1;
    if( %$toDownload ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            { 'packages-to-download' => $toDownload },
            $ret );

    return $ret;
}

1;

