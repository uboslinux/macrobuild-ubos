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
    my $imageSignKey    = $run->getVariable( 'imageSignKey', undef ); # ok if not exists
    my $checkSignatures = $run->getVariable( 'checkSignatures', 'required' );

    my $dir;
    my $tarfile;
    my $errors = 0;
    if( !defined( $updatedPackages ) || @$updatedPackages ) {
        my $buildId  = UBOS::Utils::time2string( time() );
        my $repodir  = File::Spec->rel2abs( $run->replaceVariables( $self->{repodir} ));
        $dir         = File::Spec->rel2abs( $run->replaceVariables( $self->{dir}     ));
        $tarfile     = File::Spec->rel2abs( $run->replaceVariables( $self->{tarfile} ));

        Macrobuild::Utils::ensureParentDirectoriesOf( $dir );
        Macrobuild::Utils::ensureParentDirectoriesOf( $tarfile );

        unless( -d $dir ) {
            UBOS::Utils::mkdir( $dir );
        }

        my $installCmd = 'sudo ubos-install';
        $installCmd .= " --channel $channel";
        $installCmd .= " --repository '$repodir'";
        $installCmd .= " --deviceclass $deviceclass";
        $installCmd .= " --verbose --verbose"; # for now
        $installCmd .= " --checksignatures $checkSignatures";
        $installCmd .= " --directory '$dir'";

        my $out;
        my $err;
        if( UBOS::Utils::myexec( $installCmd, undef, \$out, \$err )) {
            error( 'ubos-install failed:', $err );
            ++$errors;

        } else {
            if( UBOS::Utils::myexec( "sudo tar -c -f '$tarfile' -C '$dir' .", undef, \$out, \$err )) {
                error( 'tar failed:', $err );
                ++$errors;

            } else {
                if( UBOS::Utils::myexec( "sudo chown '\$(id -u -n):\$(id -g -n)' '$tarfile'" )) {
                    error( 'chown failed' );
                    ++$errors;
                }

                if( $imageSignKey ) {
                    my $signCmd = "gpg --detach-sign -u '$imageSignKey'--no-armor '$tarfile'";

                    if( UBOS::Utils::myexec( $signCmd, undef, \$out, \$err )) {
                        error( 'image signing failed:', $err );
                        ++$errors;
                    }
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

