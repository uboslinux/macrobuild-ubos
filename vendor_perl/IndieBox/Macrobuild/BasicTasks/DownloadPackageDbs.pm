# 
# Build one or more packages.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::DownloadPackageDbs;

use base qw( Macrobuild::Task );
use fields qw( upconfigs downloaddir );

use HTTP::Date;
use IndieBox::Macrobuild::PacmanDbFile;
use IndieBox::Macrobuild::UpConfig;
use Macrobuild::Logging;
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
    foreach my $upConfig ( values %$upConfigs ) {
        Macrobuild::Logging::debug( "Now processing upstream config file", $upConfig->name );

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
        my $cmd       = "curl '$directory/$name.db' -L -s -o '$cachedNow'$ifModifiedSinceHeader"; 

        info( "Download command:", $cmd );

        if( IndieBox::Utils::myexec( $cmd )) {
            error( "Downloading failed:", $directory );

            if( -e $cachedNow ) {
                IndieBox::Utils::deleteFile( $cachedNow );
            }
            return -1;
        }
        
        $allPackageDatabases->{$name} = new IndieBox::Macrobuild::PacmanDbFile( $upcRepoPackageDb );
        if( -e $cachedNow ) {
            info( "Have downloaded:", $cachedNow );
            if( -e $upcRepoPackageDb ) {
                IndieBox::Utils::deleteFile( $upcRepoPackageDb );
            }
            IndieBox::Utils::myexec( "mv '$cachedNow' '$upcRepoPackageDb'" );
            $updatedPackageDatabases->{$name} = $allPackageDatabases->{$name};

        } elsif( $upConfig->lastModified > (stat($upcRepoPackageDb ))[9] ) {
            # Configuration has changed since package database was updated
            $updatedPackageDatabases->{$name} = $allPackageDatabases->{$name};
            info( "Upconfig updated" );
            
        } else {
            info( "Skipped download, not updated" );
        }
    }
    $run->taskEnded( $self, {
            'all-package-databases'     => $allPackageDatabases,
            'updated-package-databases' => $updatedPackageDatabases
    } );
    if( %$updatedPackageDatabases ) {
        return 0;
    } else {
        return 1;
    }
}

1;
