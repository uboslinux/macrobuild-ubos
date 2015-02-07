# 
# Abstract superclass to create a boot image. Device-specific parts are
# factored out in methods that can be overridden in subclasses.
# Depending on parameters, this Task can:
# * install on a single partition, or on separate / and /var partitions
#   ($self->{imagesize}:   the size of the .img file to create.
#   $self->{rootpartsize}: the size of the partition in the image for /,
#                          the rest is for /var. Also understands special
#                          value 'all', in which case there is no separate
#                          /var partition
# * use ext4 or btrfs filesystems ($self->{fs})
# Also:
# * If there is a variable called adminSshKeyFile, this will create an
#   ubos-admin user with the ssh public key from that file.
# * If adminHasRoot is given, ubos-admin will have sudo access to bash
# * If linkLatest is given and the Task was successful, a symlink with the
#   name $linkLatest will be updated to point to the created image.
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::AbstractCreateBootImage;

use base qw( Macrobuild::Task );
use fields qw( repodir channel image imagesize rootpartsize fs linkLatest installPackages enableDbs startServices hostname );

use File::Spec;
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

    unless( $self->{hostname} ) {
        $self->{hostname} = 'indiebox';
    }

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

    unless( exists( $self->{channel} )) {
        error( 'Missing parameter channel' );
        return -1;
    }

    my $in              = $run->taskStarting( $self );
    my $updatedPackages = $in->{'updated-packages'};
    my $channel         = $run->replaceVariables( $self->{channel} );

    my $image;
    my $errors = 0;
    if( !defined( $updatedPackages ) || @$updatedPackages ) {
        my $buildId  = UBOS::Utils::time2string( time() );
        my $repodir  = File::Spec->rel2abs( $run->replaceVariables( $self->{repodir} ));
        $image       = File::Spec->rel2abs( $run->replaceVariables( $self->{image}   ));

        Macrobuild::Utils::ensureDirectories( $repodir );
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

        my $partitions = {};
        $errors += $self->createPartitions( $image, $partitions ); # modifies $partitions

        my @mountPathSequence = sort { $a =~ tr!/!! <=> $b =~ tr!/!! } keys %$partitions;
                # the fewer slashes, the earlier it needs mounting

        debug( 'Mount path sequence:', sub { join( ', ', @mountPathSequence ); } );

        # Mount it
        debug( "Mounting file systems" );

        my $targetDir = $image;
        $targetDir =~ s!\.img$!.mounted!;

        unless( -d $targetDir ) {
            UBOS::Utils::mkdir( $targetDir );
        }

        foreach my $mountPath ( @mountPathSequence ) {
            my $device = $partitions->{$mountPath};
            debug( 'Mounting', $device, '->', $partitions->{$mountPath} );

            unless( -d "$targetDir$mountPath" ) {
                UBOS::Utils::myexec( "sudo mkdir -p '$targetDir$mountPath'" );
            }
            UBOS::Utils::myexec( "sudo mount '$device'  '$targetDir$mountPath'" );
        }

        # Generate pacman config file for creating the image
        my $pacstrapPacmanConfig = File::Temp->new( UNLINK => 1 );
        print $pacstrapPacmanConfig <<END;
#
# Pacman config file for creating images
#

[options]
END

        if( $run->getVariable( 'sigRequiredInstall' )) {
            print $pacstrapPacmanConfig <<END;
SigLevel           = Required TrustedOnly
LocalFileSigLevel  = Required TrustedOnly
RemoteFileSigLevel = Required TrustedOnly

END
        } else {
            print $pacstrapPacmanConfig <<END;
SigLevel           = Optional
LocalFileSigLevel  = Optional
RemoteFileSigLevel = Optional

END
        }
        foreach my $db ( @{$self->{enableDbs}} ) {
            print $pacstrapPacmanConfig <<END; # Note what is and isn't escaped here

[$db]
Server = file://$repodir/$arch/$db
END
        }
        close $pacstrapPacmanConfig;

        # pacstrap
        $errors += $self->ubosPacstrap( $targetDir, $pacstrapPacmanConfig->filename );

        # hostname
        UBOS::Utils::saveFile(
                $targetDir . '/etc/hostname',
                $self->{hostname} . "\n",
                0644, 'root', 'root' );
        
        # fstab
        debug( "Generating fstab etc" );
        $errors += $self->generateFsTab( \@mountPathSequence, $partitions, $targetDir );
        $errors += $self->generateSecuretty( $targetDir );
        $errors += $self->generateOther( $targetDir );

        $errors += $self->installBootLoader( $image, $targetDir, $pacstrapPacmanConfig->filename );

        my $chrootScript = <<'END';
set -e

END

        debug( 'Enable services' );

        if( @{$self->{startServices}} ) {
            $chrootScript .= 'systemctl enable ' . join( ' ', @{$self->{startServices}} ) . "\n\n";
        }

        debug( 'Keys' );

        my $adminSshKeyFile = $run->getVariable( 'adminSshKeyFile' );
        if( $adminSshKeyFile ) {
            my $adminSshKey = UBOS::Utils::slurpFile( $adminSshKeyFile );
            $chrootScript .= <<END;
useradd -m ubos-admin
mkdir -m700 ~ubos-admin/.ssh
cat > ~ubos-admin/.ssh/authorized_keys <<KEY
$adminSshKey
KEY
chmod 600 ~ubos-admin/.ssh/authorized_keys
chown ubos-admin:ubos-admin ~ubos-admin/.ssh{,/authorized_keys}
END

            if( $run->getVariable( 'adminHasRoot' )) {
                # to help with debugging
                $chrootScript .= <<END;
cat > /etc/sudoers.d/ubos-admin <<SUDO
# ubos-admin needs to be able to perform basic admin tasks,
# but also has been allowed a root shell
ubos-admin ALL=NOPASSWD: /usr/bin/ubos-admin *, /usr/bin/bash *
SUDO
END
            } else {
                $chrootScript .= <<END;
cat > /etc/sudoers.d/ubos-admin <<SUDO
# ubos-admin needs to be able to perform basic admin tasks
ubos-admin ALL=NOPASSWD: /usr/bin/ubos-admin *
SUDO
END
            }
            $chrootScript .= <<END;
chmod 600 /etc/sudoers.d/ubos-admin
chown root:root /etc/sudoers.d/ubos-admin
END
        }

        debug( "chroot script:", $chrootScript );

        if( UBOS::Utils::myexec( "sudo arch-chroot '$targetDir'", $chrootScript, \$out, \$err )) {
            error( "chroot script failed", $err );
        }

        # Production pacman file
        
        my $productionPacmanConfig = <<END;
#
# Pacman config file for UBOS
#

[options]
Architecture = $arch
CheckSpace

SigLevel           = Required TrustedOnly
LocalFileSigLevel  = Required TrustedOnly
RemoteFileSigLevel = Required TrustedOnly

END
        foreach my $db ( @{$self->{enableDbs}} ) {
            $productionPacmanConfig .= <<END; # Note what is and isn't escaped here

[$db]
Server = http://depot.ubos.net/$channel/\$arch/$db
END
        }
        UBOS::Utils::saveFile( $targetDir . '/etc/pacman.conf', $productionPacmanConfig, 0644, 'root', 'root' );

        # Limit size of system journal
        debug( "System journal" );
        UBOS::Utils::myexec( "sudo perl -pi -e 's/^\\s*(#\\s*)?SystemMaxUse=.*\$/SystemMaxUse=50M/ '$targetDir/etc/systemd/journald.conf'" );

        # Locale
        debug( "Locale" );
        UBOS::Utils::myexec( "sudo perl -pi -e 's/^#.*en_US\.UTF-8.*\$/en_US.UTF-8 UTF-8/g' '$targetDir/etc/locale.gen'" );
        if( UBOS::Utils::myexec( "sudo arch-chroot '$targetDir' locale-gen", undef, \$out, \$err )) {
            error( "locale-gen failed", $err );
            ++$errors;
        }

        UBOS::Utils::saveFile( $targetDir . '/etc/locale.conf', "LANG=en_US.utf8\n", 0644, 'root', 'root' );

        # version
        debug( "OS version info" );
        my $issue = <<ISSUE;

+------------------------------------------+
|                                          |
|           Welcome to UBOS (tm)           |
|                                          |
|                 ubos.net                 |
|                                          |
ISSUE
        $issue .= sprintf( "|%42s|\n", "channel: $channel " );
        $issue .= <<ISSUE;
+------------------------------------------+

ISSUE
        UBOS::Utils::saveFile( $targetDir . '/etc/issue', $issue, 0644, 'root', 'root' );

        UBOS::Utils::saveFile( $targetDir . '/etc/os-release', <<OSRELEASE, 0644, 'root', 'root' );
NAME="UBOS"
ID="ubos"
ID_LIKE="arch"
PRETTY_NAME="UBOS"
HOME_URL="http://ubos.net/"
BUILD_ID="$buildId"
OSRELEASE

        # Clean up
        if( -e "$targetDir/root/.bash_history" ) {
            UBOS::Utils::deleteFile( "$targetDir/root/.bash_history" );
        }

        foreach my $mountPath ( reverse @mountPathSequence ) {
            my $device = $partitions->{$mountPath};
            debug( 'Unmounting', $mountPath, '->', $device );

            UBOS::Utils::myexec( "sudo umount '$targetDir$mountPath'" );
        }

        if( UBOS::Utils::myexec( "sudo losetup -j '$image'", undef, \$out, \$err )) {
            error( "losetup -j error:", $image, $err );
            ++$errors;
        } else {
            foreach my $line ( split "\n", $out ) {
                if( $line =~ m!^([^:]*):! ) {
                    my $device = $1;
                    UBOS::Utils::myexec( "sudo kpartx -d '$device'" );
                    UBOS::Utils::myexec( "sudo losetup -d '$device'" );
                }
            }
            UBOS::Utils::rmdir( $targetDir );
        }
    }

    if( $errors ) {
        $run->taskEnded(
                $self,
                {
                    'bootimages'   => [],
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
                    'bootimages'   => [ $image ],
                    'failedimages' => [],
                    'linkLatests'  => [ $linkLatest ]
                },
                0 );

        return 0;

    } else {
        $run->taskEnded(
                $self,
                {
                    'bootimages'   => [],
                    'failedimages' => [],
                    'linkLatests'  => []
                },
                1 );

        return 1;
    }
}

#########

##
# Create the partition(s) for this BootImage.
# $partitions: insert created partitions here as path -> device
# return: number of errors
sub createPartitions {
    my $self       = shift;
    my $partitions = shift;

    error( 'createPartitions not overridden for', ref( $self ));

    return 1;
}

##
# Generate and save a different /etc/securetty if needed
# $targetDir: the path where the bootimage has been mounted
# return: number of errors
sub generateSecuretty {
    my $self      = shift;
    my $targetDir = shift;

    # do nothing by default

    return 0;
}

##
# Generate and save different other files if needed
# $targetDir: the path where the bootimage has been mounted
# return: number of errors
sub generateOther {
    my $self      = shift;
    my $targetDir = shift;

    # do nothing by default

    return 0;
}

##
# Generate and save /etc/fstab
# $@mountPathSequence: the sequence of paths to mount
# %$partitions: map of paths to devices
# $targetDir: the path where the bootimage has been mounted
# return: number of errors
sub generateFsTab {
    my $self              = shift;
    my $mountPathSequence = shift;
    my $partitions        = shift;
    my $targetDir         = shift;

    error( 'generateFsTab not overridden for', ref( $self ));

    return 1;
}

##
# Install the bootloader for this BootImage
# $targetDir: the path where the bootimage has been mounted
# $config: pacman config file name to be used to install additional software
# return: number of errors
sub installBootLoader {
    my $self       = shift;
    my $targetDir = shift;
    my $config    = shift;

    error( 'installBootLoader not overridden for', ref( $self ));

    return 1;
}

##
# Our version of pacstrap, see https://projects.archlinux.org/arch-install-scripts.git/tree/pacstrap.in
# $targetDir: the path where the bootimage has been mounted
# $config: pacman config file name to be used to install additional software
# return: number of errors
sub ubosPacstrap {
    my $self      = shift;
    my $targetDir = shift;
    my $config    = shift;

    unless( -d $targetDir ) {
        fatal( 'targetDir does not exist', $targetDir );
    }

    my $errors = 0;

    debug( "Now pacstrap, mounting special devices" );
    my $s1 = <<END;
sudo mkdir -m 0755 -p $targetDir/var/{cache/pacman/pkg,lib/pacman,log} $targetDir/{dev,run,etc}
sudo mkdir -m 1777 -p $targetDir/tmp
sudo mkdir -m 0555 -p $targetDir/{sys,proc}

sudo mount proc   $targetDir/proc    -t proc     -o nosuid,noexec,nodev
sudo mount sys    $targetDir/sys     -t sysfs    -o nosuid,noexec,nodev,ro
sudo mount udev   $targetDir/dev     -t devtmpfs -o mode=0755,nosuid
sudo mount devpts $targetDir/dev/pts -t devpts   -o mode=0620,gid=5,nosuid,noexec
sudo mount shm    $targetDir/dev/shm -t tmpfs    -o mode=1777,nosuid,nodev
sudo mount run    $targetDir/run     -t tmpfs    -o nosuid,nodev,mode=0755
sudo mount tmp    $targetDir/tmp     -t tmpfs    -o mode=1777,strictatime,nodev,nosuid
END

    if( UBOS::Utils::myexec( $s1 )) {
        ++$errors;
    }

    debug( "Executing pacman" );
    my $pacmanCmd = "sudo pacman"
            . " -r '$targetDir'"
            . " -Sy"
            . " '--config=$config'"
            . " --cachedir '$targetDir/var/cache/pacman/pkg'"
            . " --noconfirm"
            . ' ' . join( ' ', @{$self->{installPackages}} );

    my $out;
    my $err;
    if( UBOS::Utils::myexec( $pacmanCmd, undef, \$out, \$err )) {
        error( "pacman failed:", $err, "\nconfiguration was:\n", UBOS::Utils::slurpFile( $config ) );
        ++$errors;
    }

    debug( "Pacman output:", $out );

    debug( "Unmounting special devices" );

    my $s2 = <<END;
sudo umount $targetDir/tmp
sudo umount $targetDir/run
sudo umount $targetDir/dev/shm
sudo umount $targetDir/dev/pts
sudo umount $targetDir/dev
sudo umount $targetDir/sys
sudo umount $targetDir/proc
END
    if( UBOS::Utils::myexec( $s2 )) {
        ++$errors;
    }

    return $errors;
}

1;
