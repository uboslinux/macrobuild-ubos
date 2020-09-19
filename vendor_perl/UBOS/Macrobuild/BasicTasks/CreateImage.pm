#!/usr/bin/perl
#
# Create a bootable UBOS image.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateImage;

use base qw( Macrobuild::Task );
use fields qw( arch channel installDepotRoot runDepotRoot deviceclass installCheckSignatures runCheckSignatures image imagesize linkLatest );

use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;
use Macrobuild::Task;

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

    my $errors    = 0;
    my $image     = File::Spec->rel2abs( $self->getProperty( 'image'   ));
    my $imagesize = $self->getProperty( 'imagesize' );

    UBOS::Macrobuild::Utils::ensureParentDirectoriesOf( $image );

    # Create image file
    my $out;
    if( UBOS::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=$imagesize", undef, \$out, \$out )) {
         # sparse
         error( "dd failed:", $out );
         ++$errors;
    }

    my $installCmd = 'sudo ubos-install';
    $installCmd .= " --channel $channel";
    $installCmd .= " --arch '$arch'";
    $installCmd .= " --deviceclass $deviceclass";
    $installCmd .= " --install-check-signatures $installCheckSignatures";
    $installCmd .= " --run-check-signatures $runCheckSignatures";
    if( $installDepotRoot ) {
        $installCmd .= " --install-depot-root '$installDepotRoot'";
    }
    if( $runDepotRoot ) {
        $installCmd .= " --run-depot-root '$runDepotRoot'";
    }
    # NOTE: CHANNEL dependency
    if( 'dev' eq $channel ) {
        # not in dev
        $installCmd .= " --disable-package-db hl";
        $installCmd .= " --disable-package-db hl-experimental";
    }

    if( UBOS::Logging::isTraceActive() ) {
        $installCmd .= " --verbose --verbose";
    } elsif( UBOS::Logging::isInfoActive() ) {
        $installCmd .= " --verbose";
    }
    $installCmd .= " '$image'";

    if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$out, UBOS::Logging::isInfoActive() )) { # also catch isTraceActive
        error( 'ubos-install failed:', $out, "\command was: $installCmd" );
        ++$errors;
    }

    if( $errors ) {
        $run->setOutput( {
                'image'       => [],
                'failedimage' => [ $image ],
                'linkLatest'  => []
        });

        return FAIL;

    } elsif( $image ) {
        my $linkLatest = $self->getPropertyOrDefault( 'linkLatest', undef );
        if( $linkLatest ) {
            if( -l $linkLatest ) {
                UBOS::Utils::deleteFile( $linkLatest );

            } elsif( -e $linkLatest ) {
                warning( "linkLatest $linkLatest exists, but isn't a symlink. Not updating" );
                $linkLatest = undef;
            }
            if( $linkLatest ) {
                my $relImage = UBOS::Macrobuild::Utils::relPath( $image, $linkLatest);
                UBOS::Utils::symlink( $relImage, $linkLatest );
            }
        }

        if( defined( $linkLatest )) {
            $run->setOutput( {
                    'image'       => [ $image ],
                    'failedimage' => [],
                    'linkLatest'  => [ $linkLatest ]
            });
        } else {
            $run->setOutput( {
                    'image'       => [ $image ],
                    'failedimage' => []
            });
        }

        return SUCCESS;

    } else {
        $run->setOutput( {
                'image'       => [],
                'failedimage' => [],
                'linkLatest'  => []
        });

        return DONE_NOTHING;
    }
}

1;

