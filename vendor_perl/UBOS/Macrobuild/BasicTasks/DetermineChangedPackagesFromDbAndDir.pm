#!/usr/bin/perl
#
# Determine which packages, of the ones we want, have new versions
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;

use base qw( Macrobuild::Task );
use fields qw( arch channel dir upconfigs );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch    = $self->getProperty( 'arch' );
    my $channel = $self->getProperty( 'channel' );
    my $dir     = $self->getProperty( 'dir' );

    my $in = $run->getInput();

    my $packageDatabases = $in->{'all-package-databases'};
            # This one does not work:
            #     $in->{'updated-package-databases'};
            # because several uXConfigs access the same upstream repository, and on the
            # second access, it says "not changed" although it might have in the first
            # access during the same build. As a result, some packages won't be updated.


    my $ret        = SUCCESS;
    my $errors     = 0;
    my $toDownload = {}; # WARNING: This is misnamed. It contains packages to download, but also those that we have locally already.
                         # Worse, it may contain (pinned) packages that are local and cannot be found remotely at all

    if( %$packageDatabases ) {
        my $upConfigs = $self->{upconfigs}->configs( $self );
        if( $upConfigs ) {
            foreach my $upConfigName ( sort keys %$upConfigs ) { # make predictable sequence
                my $upConfig = $upConfigs->{$upConfigName};

                trace( 'Determining changed packages in UpConfig', $upConfigName );

                my $packageDatabase = $packageDatabases->{$upConfigName};
                unless( $packageDatabase ) {
                    # wasn't updated, nothing to do
                    next;
                }
                my $upConfigDir        = "$dir/$upConfigName";
                my $packagesInDatabase = $packageDatabase->containedPackages(); # returns name => filename

                foreach my $packageName ( sort keys %{$upConfig->packages} ) { # make predictable sequence
                    my $packageInfo = $upConfig->packages->{$packageName};
                    my $packageDir  = "$upConfigDir/$packageName";

                    # in case you were wondering, here's the filtering that says which packages we want,
                    # in which version and whether we need to download something

                    my $packageFileInPackageDatabase = $packagesInDatabase->{$packageName};
                    my @packageFileLocalCandidates   = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $packageDir, $arch );

                    # It all depends on whether the upConfig specifies a particular version
                    if( exists( $packageInfo->{$channel} ) && exists( $packageInfo->{$channel}->{version} )) {
                        my $wantVersion = UBOS::Macrobuild::PackageUtils::parseVersion( $packageInfo->{$channel}->{version} );

                        if( @packageFileLocalCandidates ) {
                            my @packageFileLocalCorrectVersions = grep {
                                    UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                            UBOS::Macrobuild::PackageUtils::parsePackageFileName( $_ ),
                                            $wantVersion ) == 0
                                    } @packageFileLocalCandidates;
                            if( @packageFileLocalCorrectVersions ) {
                                # use local one, but emit warning if upstream doesn't have it
                                if( UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                        UBOS::Macrobuild::PackageUtils::parsePackageFileName( $packageFileInPackageDatabase ),
                                        $wantVersion ) != 0 )
                                {
                                    warning( 'Package', $packageName, 'exists locally as wanted version', $packageInfo->{$channel}->{version}, ', but not upstream' );

                                    my $url = $upConfig->downloadUrlForPackage( $packageFileLocalCorrectVersions[0] );
                                    $toDownload->{$upConfigName}->{$packageName} = $url; # See warning above about this being misnamed
                                }

                            } else {
                                # have some versions locally, but don't have the right version locally

                                if( UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                    UBOS::Macrobuild::PackageUtils::parsePackageFileName( $packageFileInPackageDatabase ),
                                    $wantVersion ) == 0 )
                                {
                                    my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                                    $toDownload->{$upConfigName}->{$packageName} = $url;

                                } else {
                                    error( 'Package', $packageName, 'found locally (', @packageFileLocalCandidates, ') and upstream (', $packageFileInPackageDatabase, '), but neither in wanted version', $packageInfo->{$channel}->{version} );
                                    $ret = FAIL;
                                }
                            }

                        } else {
                            # don't have local candidates
                            if( !$packageFileInPackageDatabase ) {
                                # don't have any upstream either
                                error( 'No package file found locally or upstream for package', $packageName, 'in any version, want', $packageInfo->{$channel}->{version} );
                                $ret = FAIL;

                            } elsif( UBOS::Macrobuild::PackageUtils::compareParsedPackageFileNamesByVersion(
                                UBOS::Macrobuild::PackageUtils::parsePackageFileName( $packageFileInPackageDatabase ),
                                $wantVersion ) == 0 )
                            {
                                my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                                $toDownload->{$upConfigName}->{$packageName} = $url;

                            } else {
                                error( 'Package', $packageName, 'found upstream, but as', $packageFileInPackageDatabase, ', not in wanted version', $packageInfo->{$channel}->{version} );
                                $ret = FAIL;
                            }
                        }

                    } else {
                        # use any version

                        if( @packageFileLocalCandidates ) {
                           if( $packageFileInPackageDatabase ) {
                                my $bestLocalCandidate = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @packageFileLocalCandidates ); # most recent now at bottom
                                if( UBOS::Macrobuild::PackageUtils::comparePackageFileNamesByVersion( $bestLocalCandidate, $packageFileInPackageDatabase ) < 0 ) {
                                    my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                                    $toDownload->{$upConfigName}->{$packageName} = $url;
                                } # else use local

                            } else {
                                warning( 'No package file found upstream for package', $packageName, ', using local package instead' );
                            }

                        } else {
                           if( $packageFileInPackageDatabase ) {
                                my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                                $toDownload->{$upConfigName}->{$packageName} = $url;

                            } else {
                                error( 'No package file found locally or upstream for package', $packageName, 'in any version' );
                                $ret = FAIL;
                            }
                        }
                    }
                }
            }
        } else {
            ++$errors;
        }
    }

    $run->setOutput( {
            'packages-to-download' => $toDownload
    } );

    if( $ret == FAIL || $errors ) {
        return FAIL;
    }
    if( %$toDownload ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

