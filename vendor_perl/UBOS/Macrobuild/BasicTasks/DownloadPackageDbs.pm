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
use Macrobuild::Task;
use Macrobuild::Utils;
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
        my $upcRepoDir = "$downloadDir/$name";
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

        $allPackageDatabases->{$name} = new UBOS::Macrobuild::PacmanDbFile( $upcRepoPackageDb );
        if( -e $cachedNow ) {
            trace( "Have downloaded:", $cachedNow );
            if( -e $upcRepoPackageDb ) {
                UBOS::Utils::deleteFile( $upcRepoPackageDb );
            }
            UBOS::Utils::myexec( "mv '$cachedNow' '$upcRepoPackageDb'" );
            $updatedPackageDatabases->{$name} = $allPackageDatabases->{$name};

        } elsif( $upConfig->lastModified > (stat($upcRepoPackageDb ))[9] ) {
            # Configuration has changed since package database was updated
            $updatedPackageDatabases->{$name} = $allPackageDatabases->{$name};
            trace( "Upconfig updated" );

        } else {
            trace( "Skipped download, not updated" );
        }
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
