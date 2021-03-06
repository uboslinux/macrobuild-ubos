#!/usr/bin/perl
#
# Build one or more packages.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::DownloadPackageDbs;

use base qw( Macrobuild::Task );
use fields qw( upconfigs downloaddir );

use HTTP::Date;
use UBOS::Logging;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Macrobuild::UpConfig;
use UBOS::Macrobuild::Utils;
use Macrobuild::Task;
use Time::Local;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $allPackageDatabases     = {};
    my $updatedPackageDatabases = {};
    my $upConfigs               = $self->{upconfigs}->configs( $self );
    my $downloadDir             = $self->getProperty( 'downloaddir' );

    if( $upConfigs ) {
        foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
            my $upConfig = $upConfigs->{$repoName};

            trace( "Now processing upstream config file", $upConfig->name );

            my $name      = $upConfig->name;
            my $directory = $upConfig->directory;
            my $packages  = $upConfig->packages;

            unless( defined( $packages ) && %$packages ) {
                info( "Empty package list, skipping:", $upConfig->name );
                next;
            }
            my $upcRepoDir = "$downloadDir/$repoName";
            UBOS::Macrobuild::Utils::ensureDirectories( $upcRepoDir );

            my $upcRepoPackageDb      = "$upcRepoDir/$name.db";
            my $ifModifiedSinceHeader = '';
            if( -e $upcRepoPackageDb ) {
                $ifModifiedSinceHeader = " -z '$upcRepoPackageDb'";
            } else {
                $ifModifiedSinceHeader = '';
            }

            my $cachedNow = "$upcRepoPackageDb.now"; # don't destroy the previous file if download fails
            my $cmd       = "curl '$directory/$name.db' -L -R -s -o '$cachedNow'$ifModifiedSinceHeader";

            trace( "Download command:", $cmd );

            my $err; # remote silly error message : Failed to set filetime 1505682917 on outfile: errno 2
            if( UBOS::Utils::myexec( $cmd, undef, \$err, \$err )) {
                error( "Downloading failed:", $directory, $err );

                if( -e $cachedNow ) {
                    UBOS::Utils::deleteFile( $cachedNow );
                }
                return FAIL;
            }

            $allPackageDatabases->{$repoName} = new UBOS::Macrobuild::PacmanDbFile( $upcRepoPackageDb );
            if( -e $cachedNow ) {
                trace( "Have downloaded:", $cachedNow );
                if( -e $upcRepoPackageDb ) {
                    UBOS::Utils::deleteFile( $upcRepoPackageDb );
                }
                UBOS::Utils::myexec( "mv '$cachedNow' '$upcRepoPackageDb'" );
                $updatedPackageDatabases->{$repoName} = $allPackageDatabases->{$repoName};

            } elsif( $upConfig->lastModified > (stat($upcRepoPackageDb ))[9] ) {
                # Configuration has changed since package database was updated
                $updatedPackageDatabases->{$repoName} = $allPackageDatabases->{$repoName};
                trace( "Upconfig updated" );

            } else {
                trace( "Skipped download, not updated" );
            }
        }
    } else {
        return FAIL;
    }

    $run->setOutput( {
            'all-package-databases'     => $allPackageDatabases,
            'updated-package-databases' => $updatedPackageDatabases
    } );

    if( %$updatedPackageDatabases ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;
