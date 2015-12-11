# 
# Upload a Docker image that exists in the local Docker registry.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UploadDockerImage;

use base qw( Macrobuild::Task );
use fields;

use File::Basename;
use Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in              = $run->taskStarting( $self );
    my $dockerIds       = $in->{'dockerIds'};
    my $errors          = 0;
    my @pushedDockerIds = ();

    foreach my $dockerId ( @$dockerIds ) {
        if( UBOS::Utils::myexec( "sudo docker push '$dockerId'" )) {
            error( 'Docker push failed of', $dockerId );
            ++$errors;
        } else {
            push @pushedDockerIds, $dockerId;
        }
    }

    my $ret;
    if( $errors ) {
        $ret = -1;
    } else {
        $ret = (@pushedDockerIds > 0) ? 0 : 1;
    }

    $run->taskEnded(
            $self,
            {
                'pushedDockerIds' => \@pushedDockerIds
            },
            $ret );

    return $ret;
}

1;

