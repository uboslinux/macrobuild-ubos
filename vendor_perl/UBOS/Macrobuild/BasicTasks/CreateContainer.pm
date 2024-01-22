#!/usr/bin/perl
#
# Create a directory hierarchy that can be booted in a Linux container.
# dir is the name of the directory
# tarfile is the tar file into which is being archived
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateContainer;

use base qw( Macrobuild::Task );
use fields qw(
        arch channel
        installDepotRoot runDepotRoot
        deviceclass
        installCheckSignatures runCheckSignatures
        deviceConfig
        dir tarfile linkLatest-dir linkLatest-tarfile );

use File::Basename;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch                   = $self->getProperty( 'arch' );
    my $channel                = $self->getProperty( 'channel' );
    my $installDepotRoot       = $self->getProperty( 'installDepotRoot' );
    my $runDepotRoot           = $self->getProperty( 'runDepotRoot' );
    my $deviceclass            = $self->getProperty( 'deviceclass' );
    my $installCheckSignatures = $self->getPropertyOrDefault( 'installCheckSignatures', 'always' );
    my $runCheckSignatures     = $self->getPropertyOrDefault( 'runCheckSignatures', 'always' );
    my $genSha256              = $self->getPropertyOrDefault( 'genSha256', 1 );
    my $deviceConfig           = $self->getProperty( 'deviceConfig' );

    my $errors  = 0;
    my $dir     = File::Spec->rel2abs( $self->getProperty( 'dir'     ));
    my $tarfile = File::Spec->rel2abs( $self->getProperty( 'tarfile' ));

    UBOS::Macrobuild::Utils::ensureParentDirectoriesOf( $dir );
    UBOS::Macrobuild::Utils::ensureParentDirectoriesOf( $tarfile );

    unless( -d $dir ) {
        # if this is a btrfs filesystem, create a subvolume instead of a directory
        my $parentDir = dirname( $dir );
        my $out;
        if( UBOS::Utils::myexec( "df --output=fstype '$parentDir'", undef, \$out ) == 0 ) {
           if( $out =~ m!btrfs! ) {
               if( UBOS::Utils::myexec( "sudo btrfs subvolume create '$dir' > /dev/null 2>&1" ) != 0 ) { # no output please
                   error( "Failed creating btrfs subvolume '$dir'" );
               }
           }
        } else {
            error( "df failed on '$parentDir'" );
        }
    }

    UBOS::Macrobuild::Utils::ensureDirectories( $dir );

    my $installCmd = 'sudo ubos-install';
    if( $channel ) {
        $installCmd .= " --channel $channel";
    }
    if( $arch ) {
        $installCmd .= " --arch '$arch'";
    }
    if( $deviceclass ) {
        $installCmd .= " --deviceclass $deviceclass";
    }
    if( $installCheckSignatures ) {
        $installCmd .= " --install-check-signatures $installCheckSignatures";
    }
    if( $runCheckSignatures ) {
        $installCmd .= " --run-check-signatures $runCheckSignatures";
    }
    if( $installDepotRoot ) {
        $installCmd .= " --install-depot-root '$installDepotRoot'";
    }
    if( $runDepotRoot ) {
        $installCmd .= " --run-depot-root '$runDepotRoot'";
    }
    if( $deviceConfig ) {
        $installCmd .= " --device-config '$deviceConfig'";
    }

    # NOTE: CHANNEL dependency
    if( 'dev' eq $channel ) {
        # not in dev
        $installCmd .= " --install-disable-package-db hl";
        $installCmd .= " --install-disable-package-db hl-experimental";
        $installCmd .= " --run-disable-package-db hl";
        $installCmd .= " --run-disable-package-db hl-experimental";
    }
    if( UBOS::Logging::isTraceActive() ) {
        $installCmd .= " --verbose --verbose";
    } elsif( UBOS::Logging::isInfoActive() ) {
        $installCmd .= " --verbose";
    }
    $installCmd .= " '$dir'";

    my $out;
    if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$out, UBOS::Logging::isInfoActive() )) { # also catch isTraceActive
        error( 'ubos-install failed, command-line was:', $installCmd . "\n", $out );
        ++$errors;

    } else {
        if( UBOS::Utils::myexec( "sudo tar -c -f '$tarfile' -C '$dir' .", undef, \$out, \$out )) {
            error( 'tar failed:', $out );
            ++$errors;
        } elsif( $genSha256 ) {
            if( UBOS::Utils::myexec( "sha256 '$tarfile' > '$tarfile.sha256'" )) {
                error( 'sha256 failed' );
                ++$errors;

            } elsif( UBOS::Utils::myexec( "sudo chown \$(id -u -n):\$(id -g -n) '$tarfile" . "{,.sha256}'" )) {
                error( 'chown failed' );
                ++$errors;
            }
        } else {
            if( UBOS::Utils::myexec( "sudo chown \$(id -u -n):\$(id -g -n) '$tarfile'" )) {
                error( 'chown failed' );
                ++$errors;
            }
        }
    }

    if( $errors ) {
        $run->setOutput( {
                'dir'                => [],
                'tarfile'            => [],
                'linkLatest-dir'     => [],
                'linkLatest-tarfile' => [] });

        return FAIL;

    } elsif( $tarfile ) {
        my $linkLatestDir = $self->getPropertyOrDefault( 'linkLatest-dir', undef );
        if( $linkLatestDir ) {
            if( -l $linkLatestDir ) {
                UBOS::Utils::deleteFile( $linkLatestDir );

            } elsif( -e $linkLatestDir ) {
                warning( "linkLatest $linkLatestDir exists, but isn't a symlink. Not updating" );
                $linkLatestDir = undef;
            }
            if( $linkLatestDir ) {
                my $rel = UBOS::Macrobuild::Utils::relPath( $dir, $linkLatestDir);
                UBOS::Utils::symlink( $rel, $linkLatestDir );
            }
        }
        my $linkLatestTarfile = $self->getProperty( 'linkLatest-tarfile' );
        if( $linkLatestTarfile ) {
            if( -l $linkLatestTarfile ) {
                UBOS::Utils::deleteFile( $linkLatestTarfile );

            } elsif( -e $linkLatestTarfile ) {
                warning( "linkLatest $linkLatestTarfile exists, but isn't a symlink. Not updating" );
                $linkLatestTarfile = undef;
            }
            if( $linkLatestTarfile ) {
                my $rel = UBOS::Macrobuild::Utils::relPath( $tarfile, $linkLatestTarfile );
                UBOS::Utils::symlink( $rel, $linkLatestTarfile );
            }
        }

        my $result = {};
        if( defined( $dir )) {
            $result->{dirs} = [ $dir ];
        } else {
            $result->{dirs} = [];
        }
        if( defined( $tarfile )) {
            $result->{tarfile} = [ $tarfile ];
        } else {
            $result->{tarfile} = [];
        }
        if( defined( $linkLatestDir )) {
            $result->{'linkLatest-dir'} = [ $linkLatestDir ];
        } else {
            $result->{'linkLatest-dir'} = [];
        }
        if( defined( $linkLatestDir )) {
            $result->{'linkLatest-tarfile'} = [ $linkLatestTarfile ];
        } else {
            $result->{'linkLatest-tarfile'} = [];
        }

        $run->setOutput( $result );

        return SUCCESS;

    } else {
        $run->setOutput( {
                'dir'                => [],
                'tarfile'            => [],
                'linkLatest-dir'     => [],
                'linkLatest-tarfile' => []
        });

        return DONE_NOTHING;
    }
}

1;

