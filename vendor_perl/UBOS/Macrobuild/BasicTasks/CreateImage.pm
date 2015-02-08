# 
# Create a bootable UBOS image.
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateImage;

use base qw( Macrobuild::Task );
use fields qw( channel deviceclass image imagesize linkLatest repodir );

use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;
use Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( @args );

    return $self;
}

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $arch = $run->getVariable( 'arch' );
    unless( $arch ) {
        error( 'Variable not set: arch' );
        return -1;
    }

    foreach my $key ( qw( channel deviceclass image imagesize repodir ) ) {
        unless( exists( $self->{$key} )) {
            error( 'Missing parameter', $key );
            return -1;
        }
    }

    my $in              = $run->taskStarting( $self );
    my $updatedPackages = $in->{'updated-packages'};
    my $channel         = $run->replaceVariables( $self->{channel} );
    my $deviceclass     = $run->replaceVariables( $self->{deviceclass} );

    my $image;
    my $errors = 0;
    if( !defined( $updatedPackages ) || @$updatedPackages ) {
        my $buildId  = UBOS::Utils::time2string( time() );
        my $repodir  = File::Spec->rel2abs( $run->replaceVariables( $self->{repodir} ));
        $image       = File::Spec->rel2abs( $run->replaceVariables( $self->{image}   ));

        Macrobuild::Utils::ensureParentDirectoriesOf( $image );

        my $imagesize = $self->{imagesize};
        # Create image file
        my $out;
        my $err;
        if( UBOS::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=$imagesize", undef, \$out, \$err )) {
             # sparse
             error( "dd failed:", $err );
             ++$errors;
        }

        my $installCmd = 'sudo ubos-install';
        $installCmd .= " --channel $channel";
        $installCmd .= " --repository '$repodir'";
        $installCmd .= " --deviceclass $deviceclass";
        $installCmd .= " --verbose";
        $installCmd .= " '$image'";

        if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$err )) {
            error( 'ubos-install failed:', $err );
            ++$errors;
        }
    }

    if( $errors ) {
        $run->taskEnded(
                $self,
                {
                    'images'       => [],
                    'failedimages' => [ $image ],
                    'linkLatests'  => []
                },
                -1 );

        return -1;

    } elsif( $image ) {
        my $linkLatest = $self->{linkLatest};
        if( $linkLatest ) {
            $linkLatest = $run->replaceVariables( $linkLatest );

            if( -l $linkLatest ) {
                UBOS::Utils::deleteFile( $linkLatest );

            } elsif( -e $linkLatest ) {
                warning( "linkLatest $linkLatest exists, but isn't a symlink. Not updating" );
                $linkLatest = undef;
            }
            if( $linkLatest ) {
                my $relImage = UBOS::Macrobuild::Utils::relPath( $image, $linkLatest);
                UBOS::Utils::symlink( $relImage, $linkLatest );
            }
        }

        $run->taskEnded(
                $self,
                {
                    'images'       => [ $image ],
                    'failedimages' => [],
                    'linkLatests'  => [ $linkLatest ]
                },
                0 );

        return 0;

    } else {
        $run->taskEnded(
                $self,
                {
                    'images'       => [],
                    'failedimages' => [],
                    'linkLatests'  => []
                },
                1 );

        return 1;
    }
}

1;

