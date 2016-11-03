# 
# Create a Docker image from a tarfile. Tag it with the timestamp and with
# latest, if it is latest.
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateDockerImage;

use base qw( Macrobuild::Task );
use fields qw( image dockerName );

use Cwd 'abs_path';
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

    my $in  = $run->taskStarting( $self );

    my $image            = $run->replaceVariables( $self->{image} );
    my $dockerName       = $run->replaceVariables( $self->{dockerName} );
    my $arch             = $run->getVariable( 'arch' );
    my $errors           = 0;
    my @createdImageIds  = ();
    my @createdDockerIds = ();

    unless( $image ) {
        error( 'No image provided' );
        ++$errors;
    }
    unless( $dockerName ) {
        error( 'No dockerName provided' );
        ++$errors;
    }

    my $realImage;
    my $dockerTag;
    if( -s $image ) {
        $realImage = abs_path( dirname( $image ) . '/' . readlink( $image ));
    } else {
        $realImage = $image;
    }
    $dockerTag = basename( $realImage );
    $dockerTag =~ s!\..*!!;

    my $imageId;
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

        if( UBOS::Utils::myexec( "sudo docker import '$realImage' '$dockerName:$dockerTag'", undef, \$out )) {
            error( 'Docker import failed' );
            ++$errors;
        } else {
            $imageId = $out;
            $imageId =~ s!^\s+!!;
            $imageId =~ s!\s+$!!;
            push @createdImageIds, $imageId;
            push @createdDockerIds, "$dockerName:$dockerTag";
        }
    }
    unless( $errors ) {
        if( $image =~ m!LATEST[^/]*$! ) {
            # delete first in case it exists already
            my $out;
            my $err;
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
        }
    }

    my $ret;
    if( $errors ) {
        $ret = -1;
    } else {
        $ret = (@createdImageIds > 0) ? 0 : 1;
    }

    $run->taskEnded(
            $self,
            {
                'imageIds'  => \@createdImageIds,
                'dockerIds' => \@createdDockerIds
            },
            $ret );

    return $ret;
}

1;

