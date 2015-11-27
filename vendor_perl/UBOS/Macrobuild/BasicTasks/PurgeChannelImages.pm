# 
# Purge the images in a channel. We keep the most recent, and
# the first in any given month.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PurgeChannelImages;

use base qw( Macrobuild::Task );
use fields qw( dir age );

use Cwd qw( abs_path );
use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $dir = $run->replaceVariables( $self->{dir} );

    my @allFiles = <$dir/*>;
    my @files = grep { ! -l $_ } @allFiles; # ignore symlinks

    my %categories = ();
    foreach my $file ( @files ) {
        if( $file =~ m!^$dir/(.*_)(\d{8}-\d{6})(.*)$! ) {
            my $category = "$1/$3"; # use / as separator, we know there isn't any other
            $categories{$category} = $category;
        }
    }
    debug( 'Categories', keys %categories );

    my @keepList  = ();
    my @purgeList = ();
    foreach my $category ( keys %categories ) {
        my( $prefix, $postfix ) = ( $category =~ m!^(.*)/(.*)$! );

        my @timestamps = map { m!^$dir/$prefix(.*)$postfix$! ; $1; } grep { m!^$dir/$prefix(\d{8}-\d{6})$postfix$! } @files;
        @timestamps    = sort @timestamps;

        # keep the last one
        push @keepList, ( "$dir/$prefix" . ( pop @timestamps ) . $postfix );

        my $lastMonthKept = '000000'; # long time ago
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

    debug( 'Keeping', @keepList );
    debug( 'Purging', @purgeList );

    my $ret;
    if( @purgeList ) {
        # some of these may be btrfs subvolumes
        $ret = 0;

        @purgeList = sort { length($b) - length($a) } @purgeList;

        foreach my $purge ( @purgeList ) {
            # This may or may not work, but that's fine
            UBOS::Utils::myexec( "sudo btrfs subvolume delete --commit-after '$purge/var/lib/machines' > /dev/null 2>&1" );
            
            if( UBOS::Utils::myexec( "sudo btrfs subvolume show '$purge' > /dev/null 2>&1" ) == 0 ) {
                if( UBOS::Utils::myexec( "sudo btrfs subvolume delete --commit-after '$purge'" )) {
                    error( 'Failed to delete btrfs subvolume:', $purge );
                    $ret = -1;
                }

            } else {
                unless( "sudo /bin/rm -rf '$purge'" ) {
                    error( 'Failed to purge:', $purge );
                    $ret = -1;
                }
            }
        }
    } else {
        $ret = 1;
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
                $ret = -1;
            }
        }
    }
    
    $run->taskEnded(
            $self,
            {
                'purged' => \@purgeList
                # 'kept'   => \@keepList
            },
            $ret );
    return $ret;
}

1;

