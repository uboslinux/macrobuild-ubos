#!/usr/bin/perl
#
# Build one or more packages.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BuildPackages;

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Utils;

use base qw( Macrobuild::Task );
use fields qw( sourcedir m2settingsfile m2repository );

my $failedstamp = ".build-in-progress-or-failed";

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    unless( exists( $in->{'dirs-updated'} )) {
        error( "No dirs-updated given in input" );
        return FAIL;
    }
    unless( exists( $in->{'dirs-not-updated'} )) {
        error( "No dirs-not-updated given in input" );
        return FAIL;
    }
    my $dirsUpdated    = $in->{'dirs-updated'};
    my $dirsNotUpdated = $in->{'dirs-not-updated'};

    my %allDirs = ( %$dirsUpdated, %$dirsNotUpdated );

    # determine package dependencies
    my %dirToUXConfigName   = ();
    my %packageDependencies = ();
    my %packageToDir        = ();
    my %dirToPackage        = ();
    my $sourceDir           = $self->getProperty( 'sourcedir' );
    my $alwaysRebuild       = $self->getValueOrDefault( 'alwaysRebuild', 0 );

    foreach my $uXConfigName ( sort keys %allDirs ) {
        my $subdirs = $dirsUpdated->{$uXConfigName} || $dirsNotUpdated->{$uXConfigName};

        foreach my $subdir ( @$subdirs ) {
            my $dir = "$sourceDir/$uXConfigName";
            if( $subdir && $subdir ne '.' ) {
                $dir .= "/$subdir";
            }
            $dirToUXConfigName{$dir} = $uXConfigName;

            my $packageInfo = _readVarsFromPkgbuild( "$dir/PKGBUILD" );
            my $packageArch = $packageInfo->{arch};
            my $packageName = $packageInfo->{pkgbase} || $packageInfo->{pkgname}; # handle multi-package PKGBUILDs
            my $packageVer  = $packageInfo->{pkgver};
            my $packageRel  = $packageInfo->{pkgrel};

            my $pkgFileName = "$packageName-$packageVer-$packageRel-$packageArch.pkg.tar.xz";

            # Determine whether we actually have to build
            if( $alwaysRebuild || ! -e "$dir/$pkgFileName" ) {
                trace( 'Need to build:', "$dir/$pkgFileName" );

                $packageToDir{$packageName} = $dir;
                $dirToPackage{$dir}         = $packageName;

                my %dependencies = ();
                for my $section ( 'depends', 'makedepends' ) {
                    if( $packageInfo->{$section} ) {
                        if( 'ARRAY' eq ref( $packageInfo->{section} )) {
                            map { $dependencies{$_} = 1 } @{$packageInfo->{section}};
                        } else {
                            $dependencies{$packageInfo->{$section}} = 1;
                        }
                    }
                }
                $packageDependencies{$packageName} = \%dependencies;
            } else {
                trace( 'No need to build:', "dir/$pkgFileName" );
            }
        }
    }

    trace( sub { "Package dependencies:\n" . join( "\n", map { "    $_ => " . join( ', ', map { "'$_'" } keys %{$packageDependencies{$_}} ) } keys %packageDependencies ) } );

    # determine in which sequence to build
    my @packageSequence = _determinePackageSequence( \%packageDependencies );
    my @dirSequence     = map { $packageToDir{$_} } @packageSequence;

    trace( sub { "Dir sequence is:\n" . join( "\n", map { "    $_" } @dirSequence ) } );

    # do the build, in @dirSequence
    my $ret        = DONE_NOTHING;
    my $built      = {};
    my $notRebuilt = {};

    foreach my $dir ( @dirSequence ) {

        my $packageName  = $dirToPackage{$dir};
        my $uXConfigName = $dirToUXConfigName{$dir};

        my $mostRecentPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );

        if( $alwaysRebuild || exists( $dirsUpdated->{$uXConfigName} ) || -e "$dir/$failedstamp" || !$mostRecentPackage ) {
            if( -e "$dir/$failedstamp" ) {
                trace( "Dir not updated, but failed last time, rebuilding: uXConfigName '$uXConfigName', dir '$dir', packageName $packageName" );
            } elsif( $alwaysRebuild ) {
                trace( "alwaysRebuild=1, rebuilding: uXConfigName '$uXConfigName', dir '$dir', packageName $packageName" );
            } elsif( !$mostRecentPackage ) {
                trace( "Dir not updated, but no package present. Rebuilding: uXConfigName '$uXConfigName', dir '$dir', packageName $packageName" );
            } else {
                trace( "Dir updated, rebuilding: uXConfigName '$uXConfigName', dir '$dir', packageName $packageName" );
            }
            unless( exists( $built->{$uXConfigName} )) {
                $built->{$uXConfigName} = {};
            }

            my $buildResult = $self->_buildPackage( $dir, $packageName, $built->{$uXConfigName}, $run, $alwaysRebuild );

            if( $buildResult == FAIL) {
                $ret = $buildResult;
                if( $self->{stopOnError} ) {
                    last;
                }
            } elsif( $buildResult == SUCCESS ) {
                if( $ret == DONE_NOTHING ) {
                    $ret = $buildResult; # say we did something
                }
            } # can also be 1

        } else {
            # dir not updated, and not failed last time

            trace( "Dir not updated, reusing: uXConfigName '$uXConfigName', dir '$dir', packageName $packageName, most recent package $mostRecentPackage" );
            $notRebuilt->{$uXConfigName}->{$packageName} = "$dir/$mostRecentPackage";
        }
    }
    # take out empty entries
    foreach my $key ( keys %$built ) {
        unless( keys %{$built->{$key}} ) {
            delete $built->{$key};
        }
    }

    $run->setOutput( {
            'new-packages' => $built,
            'old-packages' => $notRebuilt
    } );

    return $ret;
}

##
# Build a package if needed.
sub _buildPackage {
    my $self          = shift;
    my $dir           = shift;
    my $packageName   = shift;
    my $builtUXConfig = shift;
    my $run           = shift;
    my $alwaysRebuild = shift;

    UBOS::Utils::myexec( "touch $dir/$failedstamp" ); # in progress

    my $packageSignKey = $self->getValueOrDefault(    'packageSignKey', undef ); # ok if not exists
    my $gpgHome        = $self->getValueOrDefault(    'GNUPGHOME',      undef ); # ok if not exists
    my $m2settingsfile = $self->getPropertyOrDefault( 'm2settingsfile', undef ); # ok if not exists
    my $m2repository   = $self->getPropertyOrDefault( 'm2repository',   undef ); # ok if not exists

    my $mvn_opts = ' -DskipTests -PUBOS';
    if( $m2settingsfile ) {
        $mvn_opts .= ' --settings ' . $m2settingsfile;
    }

    my $cmd  =  "cd $dir;";
    $cmd    .= ' env -i';
    $cmd    .=   ' PATH=/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl';
    $cmd    .=   ' LANG=en_US.utf8';
    $cmd    .=   ' TERM=xterm'; # Avahi currently needs this per https://github.com/mono/mono/issues/6768

    if( $m2repository ) {
        $cmd .= " DIET4J_REPO='" . $m2repository . "'";
    }

    if( $gpgHome ) {
        $cmd .= " GNUPGHOME='$gpgHome'";
    }

    if( defined( $mvn_opts )) {
        my $trimmed = $mvn_opts;
        $trimmed =~ s/^\s+//;
        $trimmed =~ s/\s+$//;
        $cmd .= " 'MVN_OPTS=$trimmed'";
    }
    if( $packageSignKey ) {
        $cmd .= " PACKAGER='$packageSignKey'";
    }

    # Now do --cleanbuild because we only build if we don't have the file yet
    $cmd .= ' makepkg --clean --cleanbuild --syncdeps --noconfirm --ignorearch --nocheck';
    if( $alwaysRebuild ) {
        $cmd .= ' --force --cleanbuild';
    }
    # do not invoke --sign --key <key> here, due to https://bbs.archlinux.org/viewtopic.php?id=215045

    info( 'Building package', $packageName );

    my $both;
    my $result = UBOS::Utils::myexec( $cmd, undef, \$both, \$both );
    # maven writes errors to stdout :-(

    trace( 'Build command produced output:', $both );

    if( $result ) {
        if(    ( $both =~ /ERROR: A package has already been built/ )
            || ( $both =~ /ERROR: The package group has already been built/ ))
        {
            if( -e "$dir/$failedstamp" ) {
                UBOS::Utils::deleteFile( "$dir/$failedstamp" );
            }
            return DONE_NOTHING;

        } else {
            error( "makepkg in $dir failed: ", $cmd, $both );

            return FAIL;
        }

    } elsif( $both =~ m!Finished making:\s+(\S+)\s+(\S+)\s+\(! ) {
        my $builtPackageName    = $1;
        my $builtPackageVersion = $2;

        my $builtPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );

        if( $builtPackage =~ m!^\Q$builtPackageName-$builtPackageVersion\E-.+\.pkg\.tar\.(xz|gz)$! ) {
            if( $packageSignKey ) {
                my $cmd2 = "gpg --detach-sign -u '$packageSignKey' --use-agent --no-armor '$dir/$builtPackage'";
                my $out;
                if( UBOS::Utils::myexec( $cmd2, undef, \$out, \$out )) {
                    error( 'gpg failed:', $cmd2, ':', $out );
                    return FAIL;
                }
            }

            $builtUXConfig->{$packageName} = "$dir/" . $builtPackage;

            if( -e "$dir/$failedstamp" ) {
                UBOS::Utils::deleteFile( "$dir/$failedstamp" );
            }
        } else {
            error( "makepkg in $dir supposedly worked, but can't find package:", $packageName, $builtPackage, $builtPackageName, $builtPackageVersion );
            return FAIL;
        }
        return SUCCESS;

    } else {
        error( "could not find package built by makepkg in", $dir, $both );
        return FAIL;
    }
}

##
# Helper to read key variables from a PKGBUILD file
# $pkgBuild: the PKGBUILD file name
# return: name-value pairs
sub _readVarsFromPkgbuild {
    my $pkgBuild = shift;

    unless( -r $pkgBuild ) {
        error( 'Cannot read', $pkgBuild );
        return {};
    }

    my $out;
    if( UBOS::Utils::myexec( "/usr/share/macrobuild-ubos/bin/print-pkg-vars.sh '$pkgBuild'", undef, \$out )) {
        error( 'Executing PKGBUILD failed:', $pkgBuild );
        return {};
    }

    my $ret = {};
    foreach my $line ( split /\n/, $out ) {
        if( $line =~ m!^([a-z]+)\s*:\s*(.*)$! ) {
            my( $key, $value ) = ( $1, $2 );
            $value =~ s!^\s+!!;
            $value =~ s!\s+$!!;
            if( !$value ) {
                $ret->{$key} = undef;

            } elsif( $value =~ m!\s+! ) {
                # list
                $ret->{$key} = [ split( /\s+/, $value ) ];
                
            } else {
                $ret->{$key} = $value;
            }
        } else {
            warning( 'Ignoring PKGBUILD/print-pkg-vars.sh line in', $pkgBuild, ':', $line );
        }
    }

    return $ret;
}

##
# Topological sort, with thanks to https://en.wikipedia.org/wiki/Topological_sorting
#
sub _determinePackageSequence {
    my $deps = shift;
    my %done = ();
    my @ret  = ();

    # we go through %$deps, and find nodes that don't have any more dependencies.
    # a node doesn't have dependencies if
    # 1) it has none, or
    # 2) the dependency is not in %$deps and thus out of scope, or
    # 3) the dependency is in %done already.

    while( 1 ) {
        if( scalar( keys %$deps ) <= scalar( @ret )) { # let's be safe
            last;
        }
        foreach my $current ( keys %$deps ) {
            if( exists( $done{$current} )) {
                next;
            }
            my $noDeps = 1;

            foreach my $currentDep ( keys %{$deps->{$current}} ) {
                unless( exists( $deps->{$currentDep} )) {
                    next;
                }
                if( exists( $done{$currentDep} )) {
                    next;
                }
                $noDeps = 0;
                last;
            }

            if( $noDeps ) {
                $done{$current} = $current;
                push @ret, $current;
            }
        }
    }
    return @ret;
}

1;
