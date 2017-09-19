#
# Create a bootable UBOS image.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateImage;

use base qw( Macrobuild::Task );
use fields qw( channel depotRoot deviceclass image imagesize linkLatest repodir );

use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;
use Macrobuild::Task;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch = $run->getValue( 'arch' );

    my $channel         = $run->getProperty( 'channel' );
    my $depotRoot       = $run->getProperty( 'depotRoot' );
    my $deviceclass     = $run->getProperty( 'deviceclass' );
    my $checkSignatures = $run->getPropertyOrDefault( 'checkSignatures', 'required' );

    my $errors    = 0;
    my $repodir   = File::Spec->rel2abs( $run->getProperty( 'repodir' ));
    my $image     = File::Spec->rel2abs( $run->getProperty( 'image'   ));
    my $imagesize = $run->getProperty( 'imagesize' );

    Macrobuild::Utils::ensureParentDirectoriesOf( $image );

    # Create image file
    my $out;
    if( UBOS::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=$imagesize", undef, \$out, \$out )) {
         # sparse
         error( "dd failed:", $out );
         ++$errors;
    }

    my $installCmd = 'sudo ubos-install';
    $installCmd .= " --channel $channel";
    $installCmd .= " --repository '$repodir'";
    $installCmd .= " --arch '$arch'";
    $installCmd .= " --deviceclass $deviceclass";
    $installCmd .= " --checksignatures $checkSignatures";
    if( $depotRoot ) {
        $installCmd .= " --depotroot '$depotRoot'";
    }
    if( UBOS::Logging::isTraceActive() ) {
        $installCmd .= " --verbose --verbose";
    } elsif( UBOS::Logging::isInfoActive() ) {
        $installCmd .= " --verbose";
    }
    $installCmd .= " '$image'";

    if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$out, UBOS::Logging::isInfoActive() )) { # also catch isTraceActive
        error( 'ubos-install failed:', $out );
        ++$errors;
    }

    if( $errors ) {
        $run->setOutput( {
                'images'       => [],
                'failedimages' => [ $image ],
                'linkLatests'  => []
        });

        return FAIL;

    } elsif( $image ) {
        my $linkLatest = $run->getProperty( 'linkLatest' );
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

        if( defined( $linkLatest )) {
            $run->setOutput( {
                    'images'       => [ $image ],
                    'failedimages' => [],
                    'linkLatests'  => [ $linkLatest ]
            });
        } else {
            $run->setOutput( {
                    'images'       => [ $image ],
                    'failedimages' => []
            });
        }

        return SUCCESS;

    } else {
        $run->setOutput( {
                'images'       => [],
                'failedimages' => [],
                'linkLatests'  => []
        });

        return DONE_NOTHING;
    }
}

1;

