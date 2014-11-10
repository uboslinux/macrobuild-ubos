# 
# Create a boot image for the Raspberry Pi.
# For parameters, see UBOS::Macrobuild::BasicTasks::AbstractCreateBootImage.pm
# 
use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CreateBootImage_rpi;

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

    $self->{installPackages} = [ 'base', 'openssh', 'btrfs-progs', 'ubos-admin', 'ubos-networking', 'rng-tools',
                                 'linux-raspberrypi', 'raspberrypi-firmware', 'raspberrypi-firmware-bootloader',
                                 'raspberrypi-firmware-bootloader-x' ];
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
    my $bootLoopDevice;
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

+100M
a
t
c
n
p
2

+$rootpartsize
n
p
3


w
END
    } else {
        $fdiskScript = <<END;
n
p
1

+100M
a
t
c
n
p
2


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
    $bootLoopDevice = $rootLoopDevice = $varLoopDevice = "/dev/mapper/$1";
    $bootLoopDevice .= 'p1';
    $rootLoopDevice .= 'p2';
    $varLoopDevice  .= 'p3';

    debug( "loop device for /boot:", $bootLoopDevice );
    $partitions->{'/boot'} = $bootLoopDevice;
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

    if( UBOS::Utils::myexec( "sudo mkfs.vfat '$bootLoopDevice'", undef, \$out, \$err )) {
        error( "mkfs.vfat error on /boot:", $err );
        ++$errors;
    }
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
# Generate and save /etc/fstab
# $@mountPathSequence: the sequence of paths to mount
# %$partitions: map of paths to devices
# return: number of errors
sub generateFsTab {
    my $self              = shift;
    my $mountPathSequence = shift;
    my $partitions        = shift;
    
    my $fs    = $self->{fs};
    my $fsTab = <<FSTAB;
# 
# /etc/fstab: static file system information
#
# <file system>	<dir>	<type>	<options>	<dump>	<pass>
/dev/mmcblk0p1  /boot   vfat    defaults        0       0
FSTAB

    UBOS::Utils::saveFile( $targetDir . '/etc/fstab', $fsTab, 0644, 'root', 'root' );

    return 0;
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

    # Copied from the ArmLinuxARM Raspberry Pi image
    
    UBOS::Utils::saveFile( $targetDir . '/boot/cmdline.txt', <<CONTENT, 0644, 'root', 'root' );
selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=noop rootwait
CONTENT

    UBOS::Utils::saveFile( $targetDir . '/boot/config.txt', <<CONTENT, 0644, 'root', 'root' );
# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
#disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800

# for more options see http://elinux.org/RPi_config.txt

## Some over clocking settings, governor already set to ondemand

##None
#arm_freq=700
#core_freq=250
#sdram_freq=400
#over_voltage=0

##Modest
#arm_freq=800
#core_freq=300
#sdram_freq=400
#over_voltage=0

##Medium
#arm_freq=900
#core_freq=333
#sdram_freq=450
#over_voltage=2

##High
#arm_freq=950
#core_freq=450
#sdram_freq=450
#over_voltage=6

##Turbo
#arm_freq=1000
#core_freq=500
#sdram_freq=500
#over_voltage=6

gpu_mem_512=64
gpu_mem_256=64
CONTENT

    return 0;
}

1;

