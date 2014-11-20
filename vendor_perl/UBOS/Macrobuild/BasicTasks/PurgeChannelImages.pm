# 
# Purge the images in a channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PurgeChannelImages;

use base qw( Macrobuild::Task );
use fields qw( dir age );

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
    my $age = $run->replaceVariables( $self->{age} );

    my $cutoff = UBOS::Utils::time2string( time() - $age );

    debug( 'Looking for images in directory', $dir, 'created before', UBOS::Utils::time2string( $cutoff ));

    my @files = <$dir/*>;
    @files = grep { ! -s $_ } @files; # ignore symlinks

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

        if( @timestamps ) {
            my @addToPurge = map { "$dir/$prefix$_$postfix" } grep { $_ lt $cutoff } @timestamps;
            push @purgeList, @addToPurge;
        }
    }

    debug( 'Keeping', @keepList );
    debug( 'Purging', @purgeList );

    my $ret;
    if( @purgeList ) {
        if( UBOS::Utils::deleteFile( @purgeList )) {
            $ret = 0;
        } else {
            error( 'Failed to purge some files:', @purgeList );
            $ret = -1;
        }
    } else {
        $ret = 1;
    }

    $run->taskEnded(
            $self,
            {
                'purged' => \@purgeList,
                'kept'   => \@keepList
            },
            $ret );
    return $ret;
}

1;

