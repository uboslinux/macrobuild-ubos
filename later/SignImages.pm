# 
# Sign images files given by a glob
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SignImages;

use base qw( Macrobuild::Task );
use fields qw( images );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $ret = 1;
    my @signedImages;

    my $imageSignKey = $run->getVariable( 'imageSignKey', undef ); # ok if not exists
    if( $imageSignKey ) {

        my $images    = $run->replaceVariables( $self->{images} );
        my @allImages = glob $images;

        foreach my $file ( @allFiles ) {
            if( UBOS::Utils::myexec( "gpg --detach-sign '$imageSignKey' --no-armor '$file'" )) {
                error( 'image sign failed for', $file );
            } else {
                push @signedImages, $file;
                $ret = 0;
            }
        }

    } else {
        info( 'Skipping image signing, no imageSignKey available' );
    }
    
    if( $ret == 0 ) {
        $run->taskEnded(
                $self,
                { 'images' => \@signedImages },
                $ret );
    } else {
        $run->taskEnded(
                $self,
                {},
                $ret );
    }

    return $ret;
}

1;
