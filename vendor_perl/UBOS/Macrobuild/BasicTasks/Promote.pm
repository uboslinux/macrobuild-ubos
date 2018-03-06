#!/usr/bin/perl
#
# Promote packages
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Promote;

use base qw( Macrobuild::Task );
use fields qw( sourcedir stagedir dbfile dbSignKey );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Macrobuild::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    if( exists( $in->{'new-packages'} )) {
        my $stageDir  = $self->getProperty( 'stagedir' );
        my $dbSignKey = $self->getPropertyOrDefault( 'dbSignKey', undef );
        my $dbFile    = UBOS::Macrobuild::PacmanDbFile->new( $self->getProperty( 'dbfile' ));

        UBOS::Macrobuild::Utils::ensureDirectories( $stageDir );
        
        my $promoted = {};
        my @addedPackageFiles = ();
        foreach my $usConfigName ( keys %{$in->{'new-packages'}} ) {
            my $packages = $in->{'new-packages'}->{$usConfigName};

            foreach my $packageName ( keys %$packages ) {
                my $packageFile = $packages->{$packageName};
                my $stagedFile  = $packageFile;
                $stagedFile =~ s!.*/!!;
                $stagedFile = "$stageDir/$stagedFile";

                UBOS::Utils::myexec( "cp '$packageFile' '$stagedFile'" );

                if( -e "$packageFile.sig" ) {
                    UBOS::Utils::myexec( "cp '$packageFile.sig' '$stagedFile.sig'" );
                }
                $promoted->{$usConfigName}->{$packageName} = $packageFile;
                push @addedPackageFiles, $stagedFile;
            }
        }

        if( @addedPackageFiles ) {
            if( $dbFile->addPackages( $dbSignKey, \@addedPackageFiles ) == -1 ) {
                return FAIL;
            }
        }

        $run->setOutput( {
                'promoted' => $promoted
        } );
        return SUCCESS;

    } else {
        return DONE_NOTHING;
    }
}

1;


