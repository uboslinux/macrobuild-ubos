# 
# Create a boot image for the PC.
# For parameters, see UBOS::Macrobuild::BasicTasks::AbstractCreateBootImage.pm
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateBootImage_pc;

use base qw( UBOS::Macrobuild::BasicTasks::AbstractCreateBootImage );
use fields;

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

    $self->{installPackages} = [ 'base', 'openssh', 'btrfs-progs', 'ubos-admin', 'ubos-networking', 'rng-tools' ];
    $self->{enableDbs}       = [ 'os', 'hl', 'tools' ];
    $self->{startServices}   = [ 'rngd', 'ubos-admin', 'ubos-networking', 'sshd' ];

    return $self;
}

##
# Create the partition(s) for this BootImage.
# $image: the image file
# $partitions: insert created partitions here as path -> device
# return: number of errors
sub createPartitions {
    my $self       = shift;
    my $image      = shift;
    my $partitions = shift;

    my $errors = 0;

    my $rootpartsize  = $self->{rootpartsize};

    my $separateVar = ( $rootpartsize ne 'all' );
    my $fs          = $self->{fs};

    my $imageLoopDevice;
    my $rootLoopDevice;
    my $varLoopDevice;

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
    my $out;
    my $err;
    if( UBOS::Utils::myexec( "fdisk '$image'", $fdiskScript, \$out, \$err )) {
        error( 'fdisk failed', $out, $err );
        ++$errors;
    }

    # Reread partition table
    UBOS::Utils::myexec( "partprobe '$image'" ); 
        
    # Create loopback devices and figure out what they are
    debug( "Creating loop devices" );

    if( UBOS::Utils::myexec( "sudo losetup --show -f '$image'", undef, \$imageLoopDevice, \$err )) {
        error( "losetup error:", $err );
        ++$errors;
    }
    $imageLoopDevice =~ s!^\s+!!;
    $imageLoopDevice =~ s!\s+$!!;

    if( UBOS::Utils::myexec( "sudo kpartx -a '$imageLoopDevice'", undef, undef, \$err )) {
        error( "xpartx error:", $err );
        ++$errors;
    }

    $imageLoopDevice =~ m!^/dev/(.*)$!;
    $rootLoopDevice = $varLoopDevice = "/dev/mapper/$1";
    $rootLoopDevice .= 'p1';
    $varLoopDevice  .= 'p2';

    debug( "loop device for root:", $rootLoopDevice );
    $partitions->{''} = $rootLoopDevice;
    if( $separateVar ) {
        $partitions->{'/var'} = $varLoopDevice;
        debug( "loop device for /var:",  $varLoopDevice );
    }

    # This sometimes seems to be slow, let's wait a bit
    sleep( 3 );

    # Add file systems
    debug( "Formatting file systems in", $fs );

    if( UBOS::Utils::myexec( "sudo mkfs.$fs '$rootLoopDevice'", undef, \$out, \$err )) {
        error( "mkfs.$fs error on /:", $err );
        ++$errors;
    }
    if( $separateVar ) {
        if( UBOS::Utils::myexec( "sudo mkfs.$fs '$varLoopDevice'", undef, \$out, \$err )) {
            error( "mkfs.$fs error on /var:", $err );
            ++$errors;
        }
    }

    return $errors;
}


##
# Install the bootloader for this BootImage
# $image: the image file
# $targetDir: the path where the bootimage has been mounted
# return: number of errors
sub installBootLoader {
    my $self             = shift;
    my $image            = shift;
    my $targetDir        = shift;
    my $pacmanConfigFile = shift;

    my $errors = 0;

    # Ramdisk
    debug( "Generating ramdisk" );

    # The optimized ramdisk doesn't always boot, so we always skip the optimization step
    UBOS::Utils::saveFile( $targetDir . '/etc/mkinitcpio.d/linux.preset', <<'END', 0644, 'root', 'root' );
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

    my $out;
    my $err;
    if( UBOS::Utils::myexec( "sudo arch-chroot '$targetDir' mkinitcpio -p linux", undef, \$out, \$err ) ) {
        error( "Generating ramdisk failed:", $err );
        ++$errors;
    }

    # Boot loader
    debug( "Installing grub" );
    my $pacmanCmd = "sudo pacman"
            . " -r '$targetDir'"
            . " -S"
            . " '--config=" . $pacmanConfigFile . "'"
            . " --cachedir '$targetDir/var/cache/pacman/pkg'"
            . " --noconfirm"
            . " grub";
    if( UBOS::Utils::myexec( $pacmanCmd, undef, \$out, \$err )) {
        error( "pacman failed", $err );
        ++$errors;
    }
    if( UBOS::Utils::myexec( "sudo grub-install '--boot-directory=$targetDir/boot' --recheck '$image'", undef, \$out, \$err )) {
        error( "grub-install failed", $err );
        ++$errors;
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

    if( UBOS::Utils::myexec( "sudo arch-chroot '$targetDir'", $chrootScript, \$out, \$err )) {
        error( "bootloader chroot script failed", $err );
    }

    return $errors;
}

1;

