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

    $self->{installPackages} = [ 'base', 'openssh', 'btrfs-progs', 'ubos-admin', 'ubos-networking' ];
    $self->{enableDbs}       = [ 'os', 'hl', 'tools' ];
    $self->{startServices}   = [ 'ubos-admin', 'ubos-networking', 'sshd' ];

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
# Install the bootloader for this BootImage
# $image: the image file
# $targetDir: the path where the bootimage has been mounted
# return: number of errors
sub installBootLoader {
    my $self             = shift;
    my $image            = shift;
    my $targetDir        = shift;
    my $pacmanConfigFile = shift;

    # no op

    return 0;
}

1;

