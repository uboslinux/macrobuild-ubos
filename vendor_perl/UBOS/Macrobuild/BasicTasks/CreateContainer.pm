#
# Create a directory hierarchy that can be booted in a Linux container.
# dir is the name of the directory
# tarfile is the tar file into which is being archived
#
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateContainer;

use base qw( Macrobuild::Task );
use fields qw( arch channel depotRoot deviceclass checkSignatures dir repodir tarfile linkLatest-dir linkLatest-tarfile );

use File::Basename;
use Macrobuild::Task;
use Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch            = $run->getProperty( 'arch' );
    my $channel         = $run->getProperty( 'channel' );
    my $depotRoot       = $run->getProperty( 'depotRoot' );
    my $deviceclass     = $run->getProperty( 'deviceclass' );
    my $checkSignatures = $run->getPropertyOrDefault( 'checkSignatures', 'required' );

    my $errors  = 0;
    my $repodir = File::Spec->rel2abs( $run->getProperty( 'repodir' ));
    my $dir     = File::Spec->rel2abs( $run->getProperty( 'dir'     ));
    my $tarfile = File::Spec->rel2abs( $run->getProperty( 'tarfile' ));

    Macrobuild::Utils::ensureParentDirectoriesOf( $dir );
    Macrobuild::Utils::ensureParentDirectoriesOf( $tarfile );

    unless( -d $dir ) {
        # if this is a btrfs filesystem, create a subvolume instead of a directory
        my $parentDir = dirname( $dir );
        my $out;
        if( UBOS::Utils::myexec( "df --output=fstype '$parentDir'", undef, \$out ) == 0 ) {
           if( $out =~ m!btrfs! ) {
               if( UBOS::Utils::myexec( "sudo btrfs subvolume create '$dir' > /dev/null 2>&1" ) != 0 ) { # no output please
                   error( "Failed creating btrfs subvolume '$dir'" );
               }
           }
        } else {
            error( "df failed on '$parentDir'" );
        }
    }

    Macrobuild::Utils::ensureDirectories( $dir );

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
    $installCmd .= " --directory '$dir'";

    my $out;
    if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$out, UBOS::Logging::isInfoActive() )) { # also catch isTraceActive
        error( 'ubos-install failed:', $out );
        ++$errors;

    } else {
        if( UBOS::Utils::myexec( "sudo tar -c -f '$tarfile' -C '$dir' .", undef, \$out, \$out )) {
            error( 'tar failed:', $out );
            ++$errors;

        } else {
            if( UBOS::Utils::myexec( "sudo chown \$(id -u -n):\$(id -g -n) '$tarfile'" )) {
                error( 'chown failed' );
                ++$errors;
            }
        }
    }

    if( $errors ) {
        $run->setOutput( {
                'dirs'                => [],
                'tarfiles'            => [],
                'linkLatest-dirs'     => [],
                'linkLatest-tarfiles' => [] });

        return FAIL;

    } elsif( $tarfile ) {
        my $linkLatestDir = $run->getProperty( 'linkLatest-dir' );
        if( $linkLatestDir ) {
            if( -l $linkLatestDir ) {
                UBOS::Utils::deleteFile( $linkLatestDir );

            } elsif( -e $linkLatestDir ) {
                warning( "linkLatest $linkLatestDir exists, but isn't a symlink. Not updating" );
                $linkLatestDir = undef;
            }
            if( $linkLatestDir ) {
                my $rel = UBOS::Macrobuild::Utils::relPath( $dir, $linkLatestDir);
                UBOS::Utils::symlink( $rel, $linkLatestDir );
            }
        }
        my $linkLatestTarfile = $run->getProperty( 'linkLatest-tarfile' );
        if( $linkLatestTarfile ) {
            if( -l $linkLatestTarfile ) {
                UBOS::Utils::deleteFile( $linkLatestTarfile );

            } elsif( -e $linkLatestTarfile ) {
                warning( "linkLatest $linkLatestTarfile exists, but isn't a symlink. Not updating" );
                $linkLatestTarfile = undef;
            }
            if( $linkLatestTarfile ) {
                my $rel = UBOS::Macrobuild::Utils::relPath( $tarfile, $linkLatestTarfile );
                UBOS::Utils::symlink( $rel, $linkLatestTarfile );
            }
        }

        my $result = {};
        if( defined( $dir )) {
            $result->{dirs} = [ $dir ];
        } else {
            $result->{dirs} = [];
        }
        if( defined( $tarfile )) {
            $result->{tarfiles} = [ $tarfile ];
        } else {
            $result->{tarfiles} = [];
        }
        if( defined( $linkLatestDir )) {
            $result->{'linkLatest-dirs'} = [ $linkLatestDir ];
        } else {
            $result->{'linkLatest-dirs'} = [];
        }
        if( defined( $linkLatestDir )) {
            $result->{'linkLatest-tarfiles'} = [ $linkLatestTarfile ];
        } else {
            $result->{'linkLatest-tarfiles'} = [];
        }


        $run->setOutput( $result );

        return SUCCESS;

    } else {
        $run->setOutput( {
                'dirs'                => [],
                'tarfiles'            => [],
                'linkLatest-dirs'     => [],
                'linkLatest-tarfiles' => []
        });

        return DONE_NOTHING;
    }
}

1;

