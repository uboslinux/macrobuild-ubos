# 
# Convert a boot image to a VirtualBox image
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BootImageToVmdk;

use base qw( Macrobuild::Task );
use fields qw( deleteOriginal );

use File::Spec;
use UBOS::Logging;
use UBOS::Macrobuild::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in              = $run->taskStarting( $self );
    my $bootImages      = $in->{'bootimages'};
    my $vmdkImages      = [];
    my $vmdkLinkLatests = [];
    my $deleteOriginal = !defined( $self->{deleteOriginal} ) || $self->{deleteOriginal};

    my $ret;
    foreach my $bootImage ( @$bootImages ) {
        my $vmdk = $bootImage;
        $vmdk =~ s!\.img$!!;
        $vmdk .= '.vmdk';

        my $out;
        my $err;
        $ret = UBOS::Utils::myexec( "sudo VBoxManage convertfromraw '$bootImage' '$vmdk' --format VMDK", undef, \$out, \$err );
            # We run this as root because that way, VirtualBox will create ~root/.config/ files instead of ~buildmaster
        unless( $ret ) {
            my $meUser;
            my $meGroup;

            UBOS::Utils::myexec( "id -un", undef, \$meUser );
            $meUser =~ s!\s+!!g;
            UBOS::Utils::myexec( "id -gn", undef, \$meGroup );
            $meGroup =~ s!\s+!!g;

            UBOS::Utils::myexec( "sudo chown $meUser:$meGroup '$vmdk'" ); 
            UBOS::Utils::myexec( "sudo chmod 644 '$vmdk'" ); 
            push @$vmdkImages, $vmdk;
        } else {
            error( "VBoxManage convertfromraw failed", $bootImage, $err );
            push @$vmdkImages, undef; # keep the same length
        }
    }
    
    if( defined( $in->{'linkLatests'} )) {
        # symlink the VMDKs whose images were symlinked

        debug( 'Attempting vmdk linkLatests' );
        for( my $i=0 ; $i < @$bootImages ; ++$i ) {
            my $bootImage = $bootImages->[$i];
            my $vmdk      = $vmdkImages->[$i];

            debug( 'Attempting vmdk linkLatest of', $bootImage, $vmdk );

            unless( $vmdk ) {
                next;
            }

            my( $bootImageDev, $bootImageInode ) = ( stat $bootImage )[ 0, 1 ];

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
                my $max   = min( length( $bootImage ), length( $foundLinkLatest ));
                
                for( ; $start < $max; ++$start ) {
                    if( substr( $bootImage, $start, 1 ) ne substr( $foundLinkLatest, $start, 1 )) {
                        last;
                    }
                }
                for( ; $end < $max; ++$end ) {
                    if( substr( $bootImage, -$end-1, 1 ) ne substr( $foundLinkLatest, -$end-1, 1 )) {
                        last;
                    }
                }

                my $from = substr( $bootImage,       $start, length( $bootImage )-$start-$end );
                my $to   = substr( $foundLinkLatest, $start, length( $foundLinkLatest )-$start-$end );
                
                my $vmdkLinkLatest = $vmdk;
                $vmdkLinkLatest =~ s!\Q$from\E!$to!;

                debug( 'Found vmdkLinkLatest', $vmdkLinkLatest );

                if( -l $vmdkLinkLatest ) {
                    UBOS::Utils::deleteFile( $vmdkLinkLatest );

                } elsif( -e $vmdkLinkLatest ) {
                    warning( "vmdkLinkLatest $vmdkLinkLatest exists, but isn't a symlink. Not updating" );
                    $vmdkLinkLatest = undef;
                }
                if( $vmdkLinkLatest ) {
                    my $relVmdk = UBOS::Macrobuild::Utils::relPath( $vmdk, $vmdkLinkLatest );
                    UBOS::Utils::symlink( $relVmdk, $vmdkLinkLatest );
                }
            }
        }
    }
    if( $deleteOriginal ) {
        UBOS::Utils::deleteFile( @$bootImages );
    }

    $run->taskEnded(
            $self,
            {
                'vmdkimages'      => $vmdkImages,
                'vmdkLinkLatests' => $vmdkLinkLatests
            },
            $ret );

    return $ret;
}

sub min {
    my $a = shift;
    my $b = shift;
    
    return ( $a < $b ) ? $a : $b;
}

1;
