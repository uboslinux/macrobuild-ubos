#
# Upload a Docker image that exists in the local Docker registry.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UploadDockerImage;

use base qw( Macrobuild::Task );
use fields;

use File::Basename;
use Macrobuild::Task;
use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in              = $run->getInput();
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

    $run->setOutput( {
            'pushedDockerIds' => \@pushedDockerIds
    } );

    if( $errors ) {
        return FAIL;
    } elsif( @pushedDockerIds ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

