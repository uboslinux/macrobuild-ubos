# 
# Create a directory hierarchy that can be booted in a Linux container.
# dir is the name of the directory
# tarfile is the tar file into which is being archived
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateContainer;

use base qw( Macrobuild::Task );
use fields qw( channel deviceclass image dir tarfile linkLatest-dir linkLatest-tarfile repodir );

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

    my $arch = $run->getVariable( 'arch' );
    unless( $arch ) {
        error( 'Variable not set: arch' );
        return -1;
    }

    foreach my $key ( qw( channel deviceclass dir tarfile repodir ) ) {
        unless( exists( $self->{$key} )) {
            error( 'Missing parameter', $key );
            return -1;
        }
    }

    my $in              = $run->taskStarting( $self );
    my $updatedPackages = $in->{'updated-packages'};
    my $channel         = $run->replaceVariables( $self->{channel} );
    my $deviceclass     = $run->replaceVariables( $self->{deviceclass} );
    my $checkSignatures = $run->getVariable( 'checkSignatures', 'required' );

    my $dir;
    my $tarfile;
    my $errors = 0;
    if( !defined( $updatedPackages ) || @$updatedPackages ) {
        my $buildId = UBOS::Utils::time2string( time() );
        my $repodir = File::Spec->rel2abs( $run->replaceVariables( $self->{repodir} ));
        $dir        = File::Spec->rel2abs( $run->replaceVariables( $self->{dir}     ));
        $tarfile    = File::Spec->rel2abs( $run->replaceVariables( $self->{tarfile} ));

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
                
        unless( -d $dir ) {
            UBOS::Utils::mkdir( $dir );
        }

        my $installCmd = 'sudo ubos-install';
        $installCmd .= " --channel $channel";
        $installCmd .= " --repository '$repodir'";
        $installCmd .= " --deviceclass $deviceclass";
        $installCmd .= " --checksignatures $checkSignatures";
        if( UBOS::Logging::isDebugActive() ) {
            $installCmd .= " --verbose --verbose";
        } elsif( UBOS::Logging::isInfoActive() ) {
            $installCmd .= " --verbose";
        }
        $installCmd .= " --directory '$dir'";

        my $out;
        if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$out )) {
            error( 'ubos-install failed:', $out );
            ++$errors;

        } else {
            if( UBOS::Logging::isInfoActive() ) {
                # also catch isDebugActive
                info( 'ubos-install transcript (success)', $out );
            }

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
    }

    if( $errors ) {
        $run->taskEnded(
                $self,
                {
                    'dirs'                => [],
                    'tarfiles'            => [],
                    'linkLatest-dirs'     => [],
                    'linkLatest-tarfiles' => []
                },
                -1 );

        return -1;

    } elsif( $tarfile ) {
        my $linkLatestDir = $self->{"linkLatest-dir"};
        if( $linkLatestDir ) {
            $linkLatestDir = $run->replaceVariables( $linkLatestDir );

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
        my $linkLatestTarfile = $self->{"linkLatest-tarfile"};
        if( $linkLatestTarfile ) {
            $linkLatestTarfile = $run->replaceVariables( $linkLatestTarfile );

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
            

        $run->taskEnded(
                $self,
                $result,
                0 );

        return 0;

    } else {
        $run->taskEnded(
                $self,
                {
                    'dirs'                => [],
                    'tarfiles'            => [],
                    'linkLatest-dirs'     => [],
                    'linkLatest-tarfiles' => []
                },
                1 );

        return 1;
    }
}

1;

