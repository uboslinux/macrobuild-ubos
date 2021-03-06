#!/usr/bin/perl
#
# Convert one or more images to VirtualBox images
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::ImagesToVmdk;

use base qw( Macrobuild::Task );
use fields qw( deleteOriginal );

use File::Spec;
use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in              = $run->getInput();
    my $images          = $in->{'image'};
    my $linkLatests     = [];
    my $vmdkImages      = [];
    my $vmdkLinkLatests = [];
    my $deleteOriginal = !defined( $self->{deleteOriginal} ) || $self->{deleteOriginal};

    my $ret = SUCCESS;
    foreach my $image ( @$images ) {
        my $vmdk = $image;
        $vmdk =~ s!\.img$!!;
        $vmdk .= '.vmdk';

        my $out;
        my $err;
        if( UBOS::Utils::myexec( "sudo VBoxManage convertfromraw '$image' '$vmdk' --format VMDK", undef, \$out, \$err )) {
            # We run this as root because that way, VirtualBox will create ~root/.config/ files instead of ~buildmaster

            error( "VBoxManage convertfromraw failed", $image, $err );
            push @$vmdkImages, undef; # keep the same length

            $ret = FAIL;

        } else {
            my $meUser;
            my $meGroup;

            UBOS::Utils::myexec( "id -un", undef, \$meUser );
            $meUser =~ s!\s+!!g;
            UBOS::Utils::myexec( "id -gn", undef, \$meGroup );
            $meGroup =~ s!\s+!!g;

            UBOS::Utils::myexec( "sudo chown $meUser:$meGroup '$vmdk'" );
            UBOS::Utils::myexec( "sudo chmod 644 '$vmdk'" );
            push @$vmdkImages, $vmdk;

        }
    }

    if( defined( $in->{'linkLatest'} )) {
        # symlink the VMDKs whose images were symlinked

        trace( 'Attempting vmdk linkLatests' );
        for( my $i=0 ; $i < @$images ; ++$i ) {
            my $image = $images->[$i];
            my $vmdk  = $vmdkImages->[$i];

            trace( 'Attempting vmdk linkLatest of', $image, $vmdk );

            unless( $vmdk ) {
                next;
            }

            my( $imageDev, $imageInode ) = ( stat $image )[ 0, 1 ];

            my $foundLinkLatest = undef;
            foreach my $linkLatest ( @{$in->{'linkLatest'}} ) {
                my( $linkLatestDev, $linkLatestInode ) = ( stat $linkLatest )[ 0, 1 ];

                if( $linkLatestDev == $imageDev && $linkLatestInode == $imageInode ) {
                    $foundLinkLatest = $linkLatest;
                    last;
                }
            }
            push @$linkLatests, $foundLinkLatest; # whether we found it or not
            if( $foundLinkLatest ) {
                $foundLinkLatest = File::Spec->rel2abs( $foundLinkLatest );

                # look for the string that changed, and make the same change
                my $start = 0;
                my $end   = 0;
                my $max   = min( length( $image ), length( $foundLinkLatest ));

                for( ; $start < $max; ++$start ) {
                    if( substr( $image, $start, 1 ) ne substr( $foundLinkLatest, $start, 1 )) {
                        last;
                    }
                }
                for( ; $end < $max; ++$end ) {
                    if( substr( $image, -$end-1, 1 ) ne substr( $foundLinkLatest, -$end-1, 1 )) {
                        last;
                    }
                }

                my $from = substr( $image,           $start, length( $image )-$start-$end );
                my $to   = substr( $foundLinkLatest, $start, length( $foundLinkLatest )-$start-$end );

                my $vmdkLinkLatest = $vmdk;
                $vmdkLinkLatest =~ s!\Q$from\E!$to!;

                trace( 'Found vmdkLinkLatest', $vmdkLinkLatest );

                if( -l $vmdkLinkLatest ) {
                    UBOS::Utils::deleteFile( $vmdkLinkLatest );

                } elsif( -e $vmdkLinkLatest ) {
                    warning( "vmdkLinkLatest $vmdkLinkLatest exists, but isn't a symlink. Not updating" );
                    $vmdkLinkLatest = undef;
                }
                if( $vmdkLinkLatest ) {
                    my $relVmdk = UBOS::Macrobuild::Utils::relPath( $vmdk, $vmdkLinkLatest );
                    UBOS::Utils::symlink( $relVmdk, $vmdkLinkLatest );

                    push @$vmdkLinkLatests, $vmdkLinkLatest;
                }
            }
        }
    }
    if( $deleteOriginal ) {
        UBOS::Utils::deleteFile( @$images );
        UBOS::Utils::deleteFile( @$linkLatests );
    }

    $run->setOutput( {
            'vmdkimage'      => $vmdkImages,
            'vmdkLinkLatest' => $vmdkLinkLatests
    } );

    return $ret;
}

sub min {
    my $a = shift;
    my $b = shift;

    return ( $a < $b ) ? $a : $b;
}

1;
