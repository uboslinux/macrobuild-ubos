# 
# Create a boot image
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::CreateBootImage;

use base qw( Macrobuild::Task );
use fields qw( repodir image imagesize rootpartsize fs );

# imagesize: the size of the .img file to create
# rootpartsize: the size of the partition in the image for /, the rest is for /var. Also
#               understands special value 'all', in which case there is no separate /var partition

use File::Spec;
use IndieBox::Utils;
use Macrobuild::Logging;
use Macrobuild::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in              = $run->taskStarting( $self );
    my $updatedPackages = $in->{'updated-packages'};
    my $arch            = $run->getSettings->getVariable( 'arch' );

    my @images;
    my $error = 0;
    if( !defined( $updatedPackages ) || @$updatedPackages ) {
        my $repodir  = File::Spec->rel2abs( $run->replaceVariables( $self->{repodir} ));
        my $image    = File::Spec->rel2abs( $run->replaceVariables( $self->{image}   ));

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
        if( IndieBox::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=$imagesize", undef, \$out, \$err )) {
             # sparse
             error( "dd failed:", $err );
             $error = 1;
        }

        info( "Formatting image:", $image );

        # Create partition table
        my $fdiskScript;
        if( $separateVar ) {
            $fdiskScript = <<END;
n
p
1

+$rootpartsize
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


w
END
    }
        IndieBox::Utils::myexec( "fdisk '$image'", $fdiskScript, \$out, \$err ); 

        # Reread partition table
        IndieBox::Utils::myexec( "partprobe '$image'" ); 
        
        # Create loopback devices and figure out what they are
        info( "Creating loop devices" );

        if( IndieBox::Utils::myexec( "sudo losetup --show -f '$image'", undef, \$imageLoopDevice, \$err )) {
            error( "losetup error:", $err );
        }
        $imageLoopDevice =~ s!^\s+!!;
        $imageLoopDevice =~ s!\s+$!!;

        if( IndieBox::Utils::myexec( "sudo kpartx -a '$imageLoopDevice'", undef, undef, \$err )) {
            error( "xpartx error:", $err );
        }

        $imageLoopDevice =~ m!^/dev/(.*)$!;
        $rootLoopDevice = $varLoopDevice = "/dev/mapper/$1";
        $rootLoopDevice .= 'p1';
        $varLoopDevice  .= 'p2';

        debug( "loop device for root:", $rootLoopDevice );
        if( $separateVar ) {
            debug( "loop device for var:",  $varLoopDevice );
        }

        # Add file systems
        info( "Formatting file systems in", $fs );

        if( IndieBox::Utils::myexec( "sudo mkfs.$fs '$rootLoopDevice'", undef, \$out, \$err )) {
            error( "mkfs.$fs error on /:", $err );
        }
        if( $separateVar ) {
            if( IndieBox::Utils::myexec( "sudo mkfs.$fs '$varLoopDevice'", undef, \$out, \$err )) {
                error( "mkfs.$fs error on /var:", $err );
            }
        }

        # Mount it
        info( "Mounting file systems" );

        IndieBox::Utils::mkdir( $mountedRootPart );
        IndieBox::Utils::myexec( "sudo mount '$rootLoopDevice' '$mountedRootPart'" );
        if( $separateVar ) {
            IndieBox::Utils::myexec( "sudo mkdir '$mountedRootPart/var'" );
            IndieBox::Utils::myexec( "sudo mount '$varLoopDevice'  '$mountedRootPart/var'" );
        }

        # Generate pacman config file for creating the image
        my $pacstrapPacmanConfig = File::Temp->new( UNLINK => 1 );
        print $pacstrapPacmanConfig <<END;
#
# Pacman config file for creating images
#
[os]
Server = file://$repodir
END
        close $pacstrapPacmanConfig;

        # pacstrap
        $error ||= indiePacstrap( $mountedRootPart, $repodir, $pacstrapPacmanConfig->filename );

        # hostname
        my $hostname = File::Temp->new( UNLINK => 1 );
        print $hostname "indiebox\n";
        close $hostname;
        IndieBox::Utils::myexec( "sudo install -m644 " . $hostname->filename . " $mountedRootPart/etc/hostname" );
        
        # fstab
        info( "Generating fstab" );

        my $rootUuid;
        my $varUuid;
        IndieBox::Utils::myexec( "sudo blkid -s UUID -o value '$rootLoopDevice'", undef, \$rootUuid );
        $rootUuid =~ s!^\s+!!g;
        $rootUuid =~ s!\s+$!!g;

        if( $separateVar ) {
            IndieBox::Utils::myexec( "sudo blkid -s UUID -o value '$varLoopDevice'",  undef, \$varUuid );
            $varUuid  =~ s!^\s+!!g;
            $varUuid  =~ s!\s+$!!g;
        }

        my $fstab = File::Temp->new( UNLINK => 1 );
        if( $separateVar ) {
            print $fstab <<FSTAB;
#
# /etc/fstab: static file system information
#
# <file system> <dir>	<type>	<options>	<dump>	<pass>

UUID=$rootUuid     /        ext4     rw,relatime,data=ordered 0 1
UUID=$varUuid      /var     ext4     rw,relatime,data=ordered 1 1
FSTAB
        } else {
            print $fstab <<FSTAB;
#
# /etc/fstab: static file system information
#
# <file system> <dir>	<type>	<options>	<dump>	<pass>

UUID=$rootUuid     /        ext4     rw,relatime,data=ordered 0 1
FSTAB
        }
        close $fstab;

        IndieBox::Utils::myexec( "sudo install -m644 -oroot -groot " . $fstab->filename . " '$mountedRootPart/etc/fstab'" );

        # Ramdisk
        info( "Generating ramdisk" );

        if( IndieBox::Utils::myexec( "sudo arch-chroot '$mountedRootPart' mkinitcpio -p linux", undef, \$out, \$err ) ) {
            error( "Generating ramdisk failed:", $err );
            $error = 1;
        }

        # Boot loader
        info( "Installing grub" );
        my $pacmanCmd = "sudo pacman"
                . " -r '$mountedRootPart'"
                . " -S"
                . " '--config=" . $pacstrapPacmanConfig->filename . "'"
                . " --cachedir '$mountedRootPart/var/cache/pacman/pkg'"
                . " --noconfirm"
                . " grub";
        if( IndieBox::Utils::myexec( $pacmanCmd, undef, \$out, \$err )) {
            error( "pacman failed", $err );
            $error = 1;
        }
        if( IndieBox::Utils::myexec( "sudo grub-install '--boot-directory=$mountedRootPart/boot' --recheck '$image'", undef, \$out, \$err )) {
            error( "grub-install failed", $err );
            $error = 1;
        }

        # Grub config file -- this seems to be the easiest
        if( IndieBox::Utils::myexec( "sudo arch-chroot '$mountedRootPart' grub-mkconfig -o /boot/grub/grub.cfg", undef, \$out, \$err )) {
            error( "grub-mkconfig failed", $err );
            $error = 1;
        }

        # Production pacman file
        my $productionPacmanConfig = File::Temp->new( UNLINK => 1 );
        print $productionPacmanConfig <<END; # Not what is and isn't escaped here
#
# Pacman config file for Indie Box
#
#
[options]
Architecture = $arch

[os]
Server = http://depot.indiebox.net/dev/\$arch/os

[hl]
Server = http://depot.indiebox.net/dev/\$arch/hl

# [tools]
# Server = http://depot.indiebox.net/dev/\$arch/tools
END
        close $productionPacmanConfig;
        IndieBox::Utils::myexec( "sudo install -m644 " . $productionPacmanConfig->filename . " $mountedRootPart/etc/pacman.conf" );
        
        # Locale
        info( "Locale" );
        IndieBox::Utils::myexec( "sudo perl -pi -e 's/^#.*en_US\.UTF-8.*\$/en_US.UTF-8 UTF-8/g' '$mountedRootPart/etc/locale.gen'" );
        if( IndieBox::Utils::myexec( "sudo arch-chroot '$mountedRootPart' locale-gen", undef, \$out, \$err )) {
            error( "locale-gen failed", $err );
            $error = 1;
        }

        # version
        info( "OS version info" );
        my $issue = File::Temp->new( UNLINK => 1 );
        print $issue <<ISSUE;

+------------------------------------------+
|                                          |
|          Welcome to Indie Box!           |
|                                          |
|        Let's bring our data home.        |
|                                          |
+------------------------------------------+

ISSUE
        close $issue;
        IndieBox::Utils::myexec( "sudo install -m644 " . $issue->filename . " $mountedRootPart/etc/issue" );

        my $osRelease = File::Temp->new( UNLINK => 1 );
        print $osRelease <<OSRELEASE;
NAME="Indie Box"
ID=indiebox
ID_LIKE=arch
PRETTY_NAME="Indie Box"
HOME_URL="http://indieboxproject.org/"
OSRELEASE
        close $osRelease;
        IndieBox::Utils::myexec( "sudo install -m644 " . $osRelease->filename . " $mountedRootPart/etc/os-release" );

        # Clean up
        if( $separateVar ) {
            IndieBox::Utils::myexec( "sudo umount '$mountedRootPart/var'" );
        }
        IndieBox::Utils::myexec( "sudo umount '$mountedRootPart'" );
        IndieBox::Utils::myexec( "sudo kpartx -d '$imageLoopDevice'" );
        IndieBox::Utils::myexec( "sudo losetup -d '$imageLoopDevice'" );
        IndieBox::Utils::rmdir( $mountedRootPart );

        unless( $error ) {
            push @images, $image;
        }
    }

    $run->taskEnded( $self, {
            'bootimages' => \@images
    } );

    if( $error ) {
        return -1;
    } elsif( @images ) {
        return 0;
    } else {
        return 1;
    }
}

#########

## Our version of pacstrap, see https://projects.archlinux.org/arch-install-scripts.git/tree/pacstrap.in
sub indiePacstrap {
    my $targetDir = shift;
    my $repRoot   = shift;
    my $config    = shift;

    unless( -d $targetDir ) {
        Macrobuild::Logging::fatal( 'targetDir does not exist', $targetDir );
    }

    info( "Now pacstrap, mounting special devices" );
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

    IndieBox::Utils::myexec( $s1 );

    info( "Executing pacman" );
    my $pacmanCmd = "sudo pacman"
            . " -r '$targetDir'"
            . " -Sy"
            . " '--config=$config'"
            . " --cachedir '$targetDir/var/cache/pacman/pkg'"
            . " --noconfirm"
            . " base indiebox-admin";

    my $out;
    my $err;
    if( IndieBox::Utils::myexec( $pacmanCmd, undef, \$out, \$err )) {
        error( "pacstrap failed:", $err );
    }

    info( "Unmounting special devices" );

    my $s2 = <<END;
sudo umount $targetDir/tmp
sudo umount $targetDir/run
sudo umount $targetDir/dev/shm
sudo umount $targetDir/dev/pts
sudo umount $targetDir/dev
sudo umount $targetDir/sys
sudo umount $targetDir/proc
END
    IndieBox::Utils::myexec( $s2 );

    return 0;
}

1;
