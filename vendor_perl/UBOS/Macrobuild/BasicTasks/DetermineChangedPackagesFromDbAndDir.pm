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

    my $dir     = $run->{settings}->replaceVariables( $self->{dir} );
    my $channel = $run->getVariable( 'channel' );

    my $ret = 0;
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

            foreach my $packageName ( sort keys %{$upConfig->packages} ) { # make predictable sequence
                my $packageInfo = $upConfig->packages->{$packageName};

                # in case you were wondering, here's the filtering that says which packages we want,
                # in which version and whether we need to download something

                my $packageFileInPackageDatabase = $packagesInDatabase->{$packageName};
                my @packageFileLocalCandidates   = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $dir, $arch );

                # It all depends on whether the upConfig specifies a particular version
                if( exists( $packageInfo->{$channel} ) && exists( $packageInfo->{$channel}->{version} )) {
                    my $wantVersion = UBOS::Macrobuild::PackageUtils::parseVersion( $packageInfo->{$channel}->{version} );

                    if( @packageFileLocalCandidates ) {
                        if( grep { UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                        UBOS::Macrobuild::PackageUtils::parsePackageFileName( $_ ),
                                        $wantVersion ) == 0
                                  } @packageFileLocalCandidates )
                        {
                            # use local one, but emit warning if upstream doesn't have it
                            if( UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                    UBOS::Macrobuild::PackageUtils::parsePackageFileName( $packageFileInPackageDatabase ),
                                    $wantVersion ) != 0 )
                            {
                                warning( 'Package', $packageName, 'exists locally as wanted version', $packageInfo->{$channel}->{version}, ', but not upstream' );
                            }

                        } else {
                            # have some versions locally, but don't have the right version locally

                            if( UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                UBOS::Macrobuild::PackageUtils::parsePackageFileName( $packageFileInPackageDatabase ),
                                $wantVersion ) == 0 )
                            {
                                my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                                $toDownload->{$repoName}->{$packageName} = $url;

                            } else {
                                error( 'Package', $packageName, 'found locally (', @packageFileLocalCandidates, ') and upstream (', $packageFileInPackageDatabase, '), but neither in wanted version', $packageInfo->{$channel}->{version} );
                                $ret = -1;
                            }
                        }

                    } else {
                        # don't have local candidates
                        if( !$packageFileInPackageDatabase ) {
                            # don't have any upstream either
                            error( 'No package file found locally or upstream for package', $packageName, 'in any version, want', $packageInfo->{$channel}->{version} );
                            $ret = -1;

                        } elsif( UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                            UBOS::Macrobuild::PackageUtils::parsePackageFileName( $packageFileInPackageDatabase ),
                            $wantVersion ) == 0 )
                        {
                            my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                            $toDownload->{$repoName}->{$packageName} = $url;

                        } else {
                            error( 'Package', $packageName, 'found upstream, but as', $packageFileInPackageDatabase, ', not in wanted version', $packageInfo->{$channel}->{version} );
                            $ret = -1;
                        }
                    }

                } else {
                    # use any version

                    if( @packageFileLocalCandidates ) {
                       if( $packageFileInPackageDatabase ) {
                            my $bestLocalCandidate = UBOS::BasicTasks::PackageUtils::mostRecentPackageVersion( @packageFileLocalCandidates ); # most recent now at bottom
                            if( UBOS::BasicTasks::PackageUtils::comparePackageFileNamesByVersion( $bestLocalCandidate, $packageFileInPackageDatabase ) < 0 ) {
                                my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                                $toDownload->{$repoName}->{$packageName} = $url;
                            } # else use local

                        } else {
                            warning( 'No package file found upstream for package', $packageName, ', using local package instead' );
                        }

                    } else {
                       if( $packageFileInPackageDatabase ) {
                            my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                            $toDownload->{$repoName}->{$packageName} = $url;

                        } else {
                            error( 'No package file found locally or upstream for package', $packageName, 'in any version' );
                            $ret = -1;
                        }
                    }
                }
            }
        }
    }

    if( %$toDownload && $ret != -1 ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            { 'packages-to-download' => $toDownload },
            $ret );

    return $ret;
}

1;

