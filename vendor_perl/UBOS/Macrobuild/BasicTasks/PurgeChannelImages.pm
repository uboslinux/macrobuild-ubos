#!/usr/bin/perl
#
# Purge the images in a channel. We keep the most recent, and
# the first in any given month.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PurgeChannelImages;

use base qw( Macrobuild::Task );
use fields qw( dir );

use Cwd qw( abs_path );
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $dir = $self->getProperty( 'dir' );

    my @allFiles = <$dir/*>;
    my @files = grep { ! -l $_ } @allFiles; # ignore symlinks

    my %categories = ();
    foreach my $file ( @files ) {
        if( $file =~ m!^$dir/(.*_)(\d{8}-\d{6})(.*)$! ) {
            my $category = "$1/$3"; # use / as separator, we know there isn't any other, e.g.
                                    # e.g. "ubos_red_x86_64-pc_/.img"
            $categories{$category} = $category;
        }
    }
    trace( 'Categories:', keys %categories );

    my @keepList  = ();
    my @purgeList = ();
    foreach my $category ( keys %categories ) {
        my( $prefix, $postfix ) = ( $category =~ m!^(.*)/(.*)$! );

        my @timestamps = map { m!^$dir/$prefix(.*)$postfix$! ; $1; } grep { m!^$dir/$prefix(\d{8}-\d{6})$postfix$! } @files;
        @timestamps    = sort @timestamps;

        # keep the last one
        my $lastTs = pop @timestamps;
        push @keepList, ( "$dir/$prefix" . $lastTs . $postfix );

        my $lastMonthKept = ( $lastTs =~ m!^(\d{6})! );

        foreach my $ts ( @timestamps ) {
            my $yearMonth = ( $ts =~ m!^(\d{6})! );
            if( $lastMonthKept eq $yearMonth ) {
                push @purgeList, "$dir/$prefix$ts$postfix";
            } else {
                push @keepList, "$dir/$prefix$ts$postfix";
                $lastMonthKept = $yearMonth;
            }
        }
    }

    trace( 'Keeping:', @keepList );
    trace( 'Purging:', @purgeList );

    my $ret;
    if( @purgeList ) {
        # some of these may be btrfs subvolumes
        $ret = SUCCESS;

        @purgeList = sort { length($b) - length($a) } @purgeList;

        foreach my $purge ( @purgeList ) {
            if( -e "$purge/var/lib/machines" ) {
                # This may or may not work, but that's fine
                UBOS::Utils::myexec( "sudo btrfs subvolume delete --commit-after '$purge/var/lib/machines' > /dev/null 2>&1" );
            }
            if( -e "$purge/var/lib/portables" ) {
                # This may or may not work, but that's fine
                UBOS::Utils::myexec( "sudo btrfs subvolume delete --commit-after '$purge/var/lib/portables' > /dev/null 2>&1" );
            }
            if( -e "$purge/.snapshots" ) {
                # This may or may not work, but that's fine
                UBOS::Utils::myexec( "sudo btrfs subvolume delete --commit-after '$purge/.snapshots' > /dev/null 2>&1" );
            }

            if( UBOS::Utils::myexec( "sudo btrfs subvolume show '$purge' > /dev/null 2>&1" ) == 0 ) {
                if( UBOS::Utils::myexec( "sudo btrfs subvolume delete --commit-after '$purge'" )) {
                    error( 'Failed to delete btrfs subvolume:', $purge );
                    $ret = FAIL;
                }

            } else {
                if( UBOS::Utils::myexec( "sudo /bin/rm -rf '$purge'" )) {
                    error( 'Failed to purge:', $purge );
                    $ret = FAIL;
                }
            }
        }
    } else {
        $ret = DONE_NOTHING;
    }

    # delete dangling symlinks
    foreach my $file ( @allFiles ) {
        unless( -l $file ) {
            next;
        }
        my $absFile = File::Spec->rel2abs( $file ); # need of the symlink, not the target
        my $dir     = $absFile;
        $dir =~ s!/[^/]+$!!;

        my $target    = readlink( $absFile );
        my $absTarget = abs_path( "$dir/$target" );
        if( !defined( $absTarget ) || ! -e $absTarget ) {
            unless( UBOS::Utils::deleteFile( $absFile )) {
                error( 'Failed to delete symlink:', $absFile );
                $ret = FAIL;
            }
        }
    }

    $run->setOutput( {
            'purged' => \@purgeList,
            'kept'   => \@keepList
    } );

    return $ret;
}

1;

