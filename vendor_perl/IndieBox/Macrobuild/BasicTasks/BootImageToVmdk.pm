# 
# Convert a boot image to a VirtualBox image
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::BootImageToVmdk;

use base qw( Macrobuild::Task );
use fields qw();

use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in         = $run->taskStarting( $self );
    my $bootimages = $in->{'bootimages'};
    my $vmdkimages = [];

    my $ret;
    foreach my $bootimage ( @$bootimages ) {
        my $vmdk = $bootimage;
        $vmdk =~ s!\.img$!!;
        $vmdk .= '.vmdk';

        my $out;
        my $err;
        $ret = IndieBox::Utils::myexec( "sudo VBoxManage convertfromraw '$bootimage' '$vmdk' --format VMDK", undef, \$out, \$err );
            # We run this as root because that way, VirtualBox will create ~root/.config/ files instead of ~tomcat7
        unless( $ret ) {
            my $meUser;
            my $meGroup;

            IndieBox::Utils::myexec( "id -un", undef, \$meUser );
            $meUser =~ s!\s+!!g;
            IndieBox::Utils::myexec( "id -gn", undef, \$meGroup );
            $meGroup =~ s!\s+!!g;

            IndieBox::Utils::myexec( "sudo chown $meUser:$meGroup '$vmdk'" ); 
            IndieBox::Utils::myexec( "sudo chmod 644 '$vmdk'" ); 
            push @$vmdkimages, $vmdk;
        } else {
            error( "VBoxManage convertfromraw failed", $bootimage, $err );
        }
    }

    $run->taskEnded( $self, {
            'vmdkimages' => $vmdkimages
    } );

    return 0;
}

1;
