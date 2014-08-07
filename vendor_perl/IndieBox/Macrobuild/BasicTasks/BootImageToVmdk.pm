# 
# Convert a boot image to a VirtualBox image
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::BootImageToVmdk;

use base qw( Macrobuild::Task );
use fields qw();

use File::Spec;
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
            push @$vmdkimages, undef; # keep the same length
        }
    }
    
    if( defined( $in->{'linkLatests'} )) {
        # symlink the VMDKs whose images were symlinked

        for( my $i=0 ; $i < @$bootimages ; ++$i ) {
            my $bootimage = $bootimages->[$i];
            my $vmdk      = $vmdkimages->[$i];

            unless( $vmdk ) {
                next;
            }

            my( $bootImageDev, $bootImageInode ) = ( stat $bootimage )[ 0, 1 ];

            my $foundLinkLatest = undef;
            foreach my $linkLatest ( @{$in->{'linkLatests'}} ) {
                my( $linkLatestDev, $linkLatestInode ) = ( stat $linkLatest )[ 0, 1 ];
            
                if( $linkLatestDev == $bootImageDev && $linkLatestInode == $bootImageInode ) {
                    $foundLinkLatest = $linkLatest;
                    last;
                }
            }
            if( $foundLinkLatest ) {
                $foundLinkLatest = File::Spec->rel2abs( $foundLinkLatest );      

                # look for the string that changed, and make the same change
                my $start = 0;
                my $end   = 0;
                my $max   = min( length( $bootimage ), length( $foundLinkLatest ));
                
                for( ; $start < $max; ++$start ) {
                    if( substr( $bootimage, $start, 1 ) ne substr( $foundLinkLatest, $start, 1 )) {
                        last;
                    }
                }
                for( ; $end < $max; ++$end ) {
                    if( substr( $bootimage, -$end-1, 1 ) ne substr( $foundLinkLatest, -$end-1, 1 )) {
                        last;
                    }
                }

                my $from = substr( $bootimage,       $start, length( $bootimage )-$start-$end );
                my $to   = substr( $foundLinkLatest, $start, length( $foundLinkLatest )-$start-$end );
                
                my $vmdkLinkLatest = $vmdk;
                $vmdkLinkLatest =~ s!\Q$from\E!$to!;

                IndieBox::Utils::symlink( $vmdk, $vmdkLinkLatest );
            }
        }
        
    }

    $run->taskEnded( $self, {
            'vmdkimages' => $vmdkimages
    } );

    return $ret;
}

sub min {
    my $a = shift;
    my $b = shift;
    
    return ( $a < $b ) ? $a : $b;
}

1;
