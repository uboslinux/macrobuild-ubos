# 
# Build one or more packages.
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
use Macrobuild::Utils;
use Time::Local;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;
    
    my $in = $run->taskStarting( $self );

    my $allPackageDatabases     = {};
    my $updatedPackageDatabases = {};
    my $upConfigs               = $self->{upconfigs}->configs( $run->{settings} );

    foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$repoName}; 

        debug( "Now processing upstream config file", $upConfig->name );

        my $name      = $upConfig->name;
        my $directory = $upConfig->directory;
        my $packages  = $upConfig->packages;

        unless( defined( $packages ) && %$packages ) {
            info( "Empty package list, skipping:", $upConfig->name );
            next;
        }
        my $upcRepoDir = $run->replaceVariables( $self->{downloaddir} ) . "/$name";
        Macrobuild::Utils::ensureDirectories( $upcRepoDir );

        my $upcRepoPackageDb      = "$upcRepoDir/$name.db";
        my $ifModifiedSinceHeader = '';
        if( -e $upcRepoPackageDb ) {
            $ifModifiedSinceHeader = " -z '$upcRepoPackageDb'";
        } else {
            $ifModifiedSinceHeader = '';
        }
        
        my $cachedNow = "$upcRepoPackageDb.now"; # don't destroy the previous file if download fails
        my $cmd       = "curl '$directory/$name.db' -L -R -s -o '$cachedNow'$ifModifiedSinceHeader"; 

        debug( "Download command:", $cmd );

        if( UBOS::Utils::myexec( $cmd )) {
            error( "Downloading failed:", $directory );

            if( -e $cachedNow ) {
                UBOS::Utils::deleteFile( $cachedNow );
            }
            return -1;
        }
        
        $allPackageDatabases->{$name} = new UBOS::Macrobuild::PacmanDbFile( $upcRepoPackageDb );
        if( -e $cachedNow ) {
            debug( "Have downloaded:", $cachedNow );
            if( -e $upcRepoPackageDb ) {
                UBOS::Utils::deleteFile( $upcRepoPackageDb );
            }
            UBOS::Utils::myexec( "mv '$cachedNow' '$upcRepoPackageDb'" );
            $updatedPackageDatabases->{$name} = $allPackageDatabases->{$name};

        } elsif( $upConfig->lastModified > (stat($upcRepoPackageDb ))[9] ) {
            # Configuration has changed since package database was updated
            $updatedPackageDatabases->{$name} = $allPackageDatabases->{$name};
            debug( "Upconfig updated" );
            
        } else {
            debug( "Skipped download, not updated" );
        }
    }

    my $ret = 1;
    if( %$updatedPackageDatabases ) {
        $ret = 0;
    }

    $run->taskEnded(
            $self,
            {
                'all-package-databases'     => $allPackageDatabases,
                'updated-package-databases' => $updatedPackageDatabases
            },
            $ret );

    return $ret;
}

1;
