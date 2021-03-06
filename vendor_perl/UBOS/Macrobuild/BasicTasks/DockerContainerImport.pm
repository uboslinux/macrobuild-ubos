#!/usr/bin/perl
#
# Import a container directory into Docker.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::DockerContainerImport;

use base qw( Macrobuild::Task );
use fields qw( image dockerName );

use Cwd 'abs_path';
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

    my $in                 = $run->getInput();
    my $tarFiles           = $in->{'tarfile'};
    my $linkLatestTarFiles = $in->{'linkLatest-tarfile'};
    my $dockerName         = $self->getProperty( 'dockerName' );
    my $errors             = 0;
    my @createdImageIds    = ();
    my @createdDockerIds   = ();

    if( @$tarFiles != 1 ) {
        error( 'Cannot process more than one Docker tarfile at a time:', @$tarFiles );
        ++$errors;

    } elsif( @$linkLatestTarFiles > 1 ) {
        error( 'Cannot process more than one Docker linkLatest tarfile at a time:', @$linkLatestTarFiles );
        ++$errors;

    } else {
        my $tarFile           = $tarFiles->[0];
        my $linkLatestTarFile = @$linkLatestTarFiles > 0 ? $linkLatestTarFiles->[0] : undef;

        my $realTarFile;
        my $dockerTag;
        my $imageId;

        if( -l $tarFile ) {
            $realTarFile = abs_path( dirname( $tarFile ) . '/' . readlink( $tarFile ));
        } else {
            $realTarFile = abs_path( $tarFile );
        }

        $dockerTag = basename( $realTarFile );
        $dockerTag =~ s!\..*!!;

        unless( $errors ) {
            # delete first in case it exists already
            my $out;
            my $err;
            if( UBOS::Utils::myexec( "sudo docker rmi '$dockerName:$dockerTag'", undef, \$out, \$err )) {
                unless( "$out$err" =~ m!No such image! ) {
                    error( 'Failed to delete image', "$dockerName:$dockerTag", $out, $err );
                    ++$errors;
                }
            }

            my $flags = " --change 'CMD /usr/lib/systemd/systemd'";

            if( UBOS::Utils::myexec( "sudo docker import$flags '$realTarFile' '$dockerName:$dockerTag'", undef, \$out )) {
                error( 'Docker import failed' );
                ++$errors;

            } else {
                $imageId = $out;
                $imageId =~ s!^\s+!!;
                $imageId =~ s!\s+$!!;

                push @createdImageIds, $imageId;
                push @createdDockerIds, "$dockerName:$dockerTag";
            }
        
            if( $linkLatestTarFile && -l $linkLatestTarFile ) {
                my $destFile = abs_path( dirname( $linkLatestTarFile ) . '/' . readlink( $linkLatestTarFile ));

                if( $destFile eq $realTarFile ) {
                    # delete first in case it exists already
                    if( UBOS::Utils::myexec( "sudo docker rmi '$dockerName:latest'", undef, \$out, \$err )) {
                        unless( "$out$err" =~ m!No such image! ) {
                            error( 'Failed to delete image', "$dockerName:$dockerTag", $out, $err );
                            ++$errors;
                        }
                    }

                    if( UBOS::Utils::myexec( "sudo docker tag '$imageId' '$dockerName:latest'" )) {
                        error( 'Docker tag failed' );
                        ++$errors;
                    } else {
                        push @createdDockerIds, "$dockerName:latest";
                    }
                } else {
                    warning( 'Cannot find linkLatestTarFile in this batch:', $linkLatestTarFile );
                }
            }
        }
    }

    $run->setOutput( {
            'imageIds'  => \@createdImageIds,
            'dockerIds' => \@createdDockerIds
    });

    if( $errors ) {
        return FAIL;
    } elsif( @createdImageIds ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

