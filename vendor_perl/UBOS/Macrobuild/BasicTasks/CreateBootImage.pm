# 
# Create a boot image. Depending on parameters, this Task can:
# * install on a single partition, or on separate / and /var partitions
#   ($self->{imagesize} and $self->{rootpartsize})
# * use ext4 or btrfs filesystems ($self->{fs})
# * produce an image file, or a VirtualBox-VMDK file with virtualbox-guest
#   and cloud-init modules installed ($self->{type})
# Also:
# * If there is a variable called adminSshKeyFile, this will create an
#   ubos-admin user with the ssh public key from that file.
# * If adminHasRoot is given, ubos-admin will have sudo access to bash
# * If linkLatest is given and the Task was successful, a symlink with the
#   name $linkLatest will be updated to point to the created image.
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateBootImage;

use base qw( Macrobuild::Task );
use fields qw( repodir channel image imagesize rootpartsize fs type linkLatest );

# imagesize: the size of the .img file to create
# rootpartsize: the size of the partition in the image for /, the rest is for /var. Also
#               understands special value 'all', in which case there is no separate /var partition

use File::Spec;
use UBOS::Logging;
use UBOS::Macrobuild::FileUtils;
use UBOS::Utils;
use Macrobuild::Utils;

my $dataByType = {
    'img'      => {
        'packages' => [ 'base', 'openssh', 'btrfs-progs', 'ubos-admin', 'ubos-networking' ],
        'repos'    => [ 'os', 'hl', 'tools' ],
        'services' => [ 'ubos-admin', 'ubos-networking', 'sshd' ]
    },
    'vbox.img' => {
        'packages' => [ 'base', 'openssh', 'btrfs-progs', 'ubos-admin', 'ubos-networking', 'virtualbox-guest', 'cloud-init', 'rng-tools' ],
        'repos'    => [ 'os', 'hl', 'tools', 'virt' ],
        'services' => [ 'vboxservice', 'ubos-admin', 'ubos-networking', 'sshd', 'rngd', 'cloud-final' ]
    }
};

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in              = $run->taskStarting( $self );
    my $updatedPackages = $in->{'updated-packages'};
    my $arch            = $run->getSettings->getVariable( 'arch' );

    unless( exists( $self->{type} )) {
        error( 'Missing parameter type' );
        return -1;
    }
    unless( exists( $self->{channel} )) {
        error( 'Missing parameter channel' );
        return -1;
    }
    unless( defined( $dataByType->{$self->{type}} )) {
        error( 'Invalid parameter type:', $self->{type} );
        return -1;
    }
    my $channel = $run->replaceVariables( $self->{channel} );

    my $image;
    my $error = 0;
    if( !defined( $updatedPackages ) || @$updatedPackages ) {
        my $repodir  = File::Spec->rel2abs( $run->replaceVariables( $self->{repodir} ));
        $image       = File::Spec->rel2abs( $run->replaceVariables( $self->{image}   ));

        Macrobuild::Utils::ensureDirectories( $repodir );
        Macrobuild::Utils::ensureParentDirectoriesOf( $image );

        my $imagesize     = $self->{imagesize};
        my $rootpartsize  = $self->{rootpartsize};

        my $separateVar = ( $rootpartsize ne 'all' );
        my $fs          = $self->{fs};

        my $noext = $image;
        $noext =~ s!\.img$!!;

        my $mountedRootPart = "$noext-root.mounted";
        my $mountedVarPart  = "$noext-var.mounted";

        my $imageLoopDevice;
        my $rootLoopDevice;
        my $varLoopDevice;

        # Create image file
        my $out;
        my $err;
        if( UBOS::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=$imagesize", undef, \$out, \$err )) {
             # sparse
             error( "dd failed:", $err );
             ++$error;
        }

        debug( "Formatting image:", $image );

        # Create partition table
        my $fdiskScript;
        if( $separateVar ) {
            $fdiskScript = <<END;
n
p
1

+$rootpartsize
a
n
p
2


w
END
        } else {
            $fdiskScript = <<END;
n
p
1


a
w
END
    }
        UBOS::Utils::myexec( "fdisk '$image'", $fdiskScript, \$out, \$err ); 

        # Reread partition table
        UBOS::Utils::myexec( "partprobe '$image'" ); 
        
        # Create loopback devices and figure out what they are
        debug( "Creating loop devices" );

        if( UBOS::Utils::myexec( "sudo losetup --show -f '$image'", undef, \$imageLoopDevice, \$err )) {
            error( "losetup error:", $err );
            ++$error;
        }
        $imageLoopDevice =~ s!^\s+!!;
        $imageLoopDevice =~ s!\s+$!!;

        if( UBOS::Utils::myexec( "sudo kpartx -a '$imageLoopDevice'", undef, undef, \$err )) {
            error( "xpartx error:", $err );
            ++$error;
        }

        $imageLoopDevice =~ m!^/dev/(.*)$!;
        $rootLoopDevice = $varLoopDevice = "/dev/mapper/$1";
        $rootLoopDevice .= 'p1';
        $varLoopDevice  .= 'p2';

        debug( "loop device for root:", $rootLoopDevice );
        if( $separateVar ) {
            debug( "loop device for var:",  $varLoopDevice );
        }

        # This sometimes seems to be slow, let's wait a bit
        sleep( 3 );

        # Add file systems
        debug( "Formatting file systems in", $fs );

        if( UBOS::Utils::myexec( "sudo mkfs.$fs '$rootLoopDevice'", undef, \$out, \$err )) {
            error( "mkfs.$fs error on /:", $err );
            ++$error;
        }
        if( $separateVar ) {
            if( UBOS::Utils::myexec( "sudo mkfs.$fs '$varLoopDevice'", undef, \$out, \$err )) {
                error( "mkfs.$fs error on /var:", $err );
                ++$error;
            }
        }

        # Mount it
        debug( "Mounting file systems" );

        UBOS::Utils::mkdir( $mountedRootPart );
        UBOS::Utils::myexec( "sudo mount '$rootLoopDevice' '$mountedRootPart'" );
        if( $separateVar ) {
            UBOS::Utils::myexec( "sudo mkdir '$mountedRootPart/var'" );
            UBOS::Utils::myexec( "sudo mount '$varLoopDevice'  '$mountedRootPart/var'" );
        }

        # Generate pacman config file for creating the image
        my $pacstrapPacmanConfig = File::Temp->new( UNLINK => 1 );
        print $pacstrapPacmanConfig <<END;
#
# Pacman config file for creating images
#

[options]
END

        if( $run->getSettings->getVariable( 'sigRequiredInstall' )) {
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
        foreach my $repo ( @{$dataByType->{$self->{type}}->{repos}} ) {
            print $pacstrapPacmanConfig <<END; # Note what is and isn't escaped here

[$repo]
Server = file://$repodir/$arch/$repo
END
        }
        close $pacstrapPacmanConfig;

        # pacstrap
        $error += $self->ubosPacstrap( $mountedRootPart, $pacstrapPacmanConfig->filename );

        # hostname
        UBOS::Utils::saveFile( $mountedRootPart . '/etc/hostname', "indiebox\n", 0644, 'root', 'root' );
        
        # fstab
        debug( "Generating fstab" );

        my $rootUuid;
        my $varUuid;
        UBOS::Utils::myexec( "sudo blkid -s UUID -o value '$rootLoopDevice'", undef, \$rootUuid );
        $rootUuid =~ s!^\s+!!g;
        $rootUuid =~ s!\s+$!!g;

        if( $separateVar ) {
            UBOS::Utils::myexec( "sudo blkid -s UUID -o value '$varLoopDevice'",  undef, \$varUuid );
            $varUuid  =~ s!^\s+!!g;
            $varUuid  =~ s!\s+$!!g;
        }

        if( $separateVar ) {
            UBOS::Utils::saveFile( $mountedRootPart . '/etc/fstab', <<FSTAB, 0644, 'root', 'root' );
#
# /etc/fstab: static file system information
#
# <file system> <dir>	<type>	<options>	<dump>	<pass>

UUID=$rootUuid     /        $fs     rw,relatime 0 1
UUID=$varUuid      /var     $fs     rw,relatime 1 1
FSTAB
        } else {
            UBOS::Utils::saveFile( $mountedRootPart . '/etc/fstab', <<FSTAB, 0644, 'root', 'root' );
#
# /etc/fstab: static file system information
#
# <file system> <dir>	<type>	<options>	<dump>	<pass>

UUID=$rootUuid     /        $fs     rw,relatime 0 1
FSTAB
        }

        # Ramdisk
        debug( "Generating ramdisk" );
        # The optimized ramdisk doesn't always boot, so we always skip the optimization step
        UBOS::Utils::saveFile( $mountedRootPart . '/etc/mkinitcpio.d/linux.preset', <<'END', 0644, 'root', 'root' );
# mkinitcpio preset file for the 'linux' package, modified for UBOS
#
# Do not autodetect, as the device booting the image is most likely different
# from the device that created the image

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default')

#default_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-linux.img"
default_options="-S autodetect"
END

        if( UBOS::Utils::myexec( "sudo arch-chroot '$mountedRootPart' mkinitcpio -p linux", undef, \$out, \$err ) ) {
            error( "Generating ramdisk failed:", $err );
            ++$error;
        }

        # Boot loader
        debug( "Installing grub" );
        my $pacmanCmd = "sudo pacman"
                . " -r '$mountedRootPart'"
                . " -S"
                . " '--config=" . $pacstrapPacmanConfig->filename . "'"
                . " --cachedir '$mountedRootPart/var/cache/pacman/pkg'"
                . " --noconfirm"
                . " grub";
        if( UBOS::Utils::myexec( $pacmanCmd, undef, \$out, \$err )) {
            error( "pacman failed", $err );
            ++$error;
        }
        if( UBOS::Utils::myexec( "sudo grub-install '--boot-directory=$mountedRootPart/boot' --recheck '$image'", undef, \$out, \$err )) {
            error( "grub-install failed", $err );
            ++$error;
        }
        
        # Create a script that can be passed to arch-chroot:
        # 1. grub configuration
        # 2. Depmod so modules can be found. This needs to use the image's kernel version,
        #    not the currently running one
        # 3. Default "run-level" (multi-user, not graphical)
        # 4. Enable services
        
        my $chrootScript = <<'END';
set -e

grub-mkconfig -o /boot/grub/grub.cfg

for v in $(ls -1 /lib/modules | grep -v extramodules); do depmod -a $v; done

systemctl set-default multi-user.target
END

        # "run-level". we want multi-user, but not graphical
        


        if( @{$dataByType->{$self->{type}}->{services}} ) {
            $chrootScript .= 'systemctl enable ' . join( ' ', @{$dataByType->{$self->{type}}->{services}} ) . "\n\n";
        }
        my $adminSshKeyFile = $run->getSettings->getVariable( 'adminSshKeyFile' );
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

            if( $run->getSettings->getVariable( 'adminHasRoot' )) {
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

        if( UBOS::Utils::myexec( "sudo arch-chroot '$mountedRootPart'", $chrootScript, \$out, \$err )) {
            error( "chroot script failed", $err );
        }

        # Production pacman file
        
        my $productionPacmanConfig = <<END;
#
# Pacman config file for UBOS
#

[options]
Architecture = $arch

SigLevel           = Required TrustedOnly
LocalFileSigLevel  = Required TrustedOnly
RemoteFileSigLevel = Required TrustedOnly

END
        foreach my $repo ( @{$dataByType->{$self->{type}}->{repos}} ) {
            $productionPacmanConfig .= <<END; # Note what is and isn't escaped here

[$repo]
Server = http://depot.ubos.net/$channel/\$arch/$repo
END
        }
        UBOS::Utils::saveFile( $mountedRootPart . '/etc/pacman.conf', $productionPacmanConfig, 0644, 'root', 'root' );
        
        # Locale
        debug( "Locale" );
        UBOS::Utils::myexec( "sudo perl -pi -e 's/^#.*en_US\.UTF-8.*\$/en_US.UTF-8 UTF-8/g' '$mountedRootPart/etc/locale.gen'" );
        if( UBOS::Utils::myexec( "sudo arch-chroot '$mountedRootPart' locale-gen", undef, \$out, \$err )) {
            error( "locale-gen failed", $err );
            ++$error;
        }

        UBOS::Utils::saveFile( $mountedRootPart . '/etc/locale.conf', "LANG=en_US.utf8\n", 0644, 'root', 'root' );

        # version
        debug( "OS version info" );
        my $issue = <<ISSUE;

+------------------------------------------+
|                                          |
|             Welcome to UBOS              |
|                                          |
|                 ubos.net                 |
|                                          |
ISSUE
        $issue .= sprintf( "|%42s|\n", "channel: $channel " );
        $issue .= <<ISSUE;
+------------------------------------------+

ISSUE
        UBOS::Utils::saveFile( $mountedRootPart . '/etc/issue', $issue, 0644, 'root', 'root' );

        UBOS::Utils::saveFile( $mountedRootPart . '/etc/os-release', <<OSRELEASE, 0644, 'root', 'root' );
NAME="UBOS"
ID=ubos
ID_LIKE=arch
PRETTY_NAME="UBOS"
HOME_URL="http://ubos.net/"
OSRELEASE

        # Clean up
        if( -e "$mountedRootPart/root/.bash_history" ) {
            UBOS::Utils::deleteFile( "$mountedRootPart/root/.bash_history" );
        }
        if( $separateVar ) {
            UBOS::Utils::myexec( "sudo umount '$mountedRootPart/var'" );
        }
        UBOS::Utils::myexec( "sudo umount '$mountedRootPart'" );
        UBOS::Utils::myexec( "sudo kpartx -d '$imageLoopDevice'" );
        UBOS::Utils::myexec( "sudo losetup -d '$imageLoopDevice'" );
        UBOS::Utils::rmdir( $mountedRootPart );
    }

    if( $error ) {
        $run->taskEnded( $self, {
                'bootimages'   => [],
                'failedimages' => [ $image ],
                'linkLatests'  => []
        } );

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
                my $relImage = UBOS::Macrobuild::FileUtils::relPath( $image, $linkLatest);
                UBOS::Utils::symlink( $relImage, $linkLatest );
            }
        }

        $run->taskEnded( $self, {
                'bootimages'   => [ $image ],
                'failedimages' => [],
                'linkLatests'  => [ $linkLatest ]
        } );

        return 0;

    } else {
        $run->taskEnded( $self, {
                'bootimages'   => [],
                'failedimages' => [],
                'linkLatests'  => []
        } );

        return 1;
    }
}

#########

## Our version of pacstrap, see https://projects.archlinux.org/arch-install-scripts.git/tree/pacstrap.in
sub ubosPacstrap {
    my $self      = shift;
    my $targetDir = shift;
    my $config    = shift;

    unless( -d $targetDir ) {
        fatal( 'targetDir does not exist', $targetDir );
    }

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

    UBOS::Utils::myexec( $s1 );

    debug( "Executing pacman" );
    my $pacmanCmd = "sudo pacman"
            . " -r '$targetDir'"
            . " -Sy"
            . " '--config=$config'"
            . " --cachedir '$targetDir/var/cache/pacman/pkg'"
            . " --noconfirm"
            . ' ' . join( ' ', @{$dataByType->{$self->{type}}->{packages}} );

    my $out;
    my $err;
    if( UBOS::Utils::myexec( $pacmanCmd, undef, \$out, \$err )) {
        error( "pacman failed:", $err, "\nconfiguration was:\n", UBOS::Utils::slurpFile( $config ) );
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
    UBOS::Utils::myexec( $s2 );

    return 0;
}

1;
