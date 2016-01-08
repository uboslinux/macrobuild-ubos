# 
# Creates all images for the PC
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_pc;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::CreateImage;
use UBOS::Macrobuild::BasicTasks::ImagesToVmdk;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    my $deviceclass = 'pc';

    $self->SUPER::new( %args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin( 
                'parallelTasks' => {
                    'img' => new UBOS::Macrobuild::BasicTasks::CreateImage(
                        'name'         => 'Create ' . $deviceclass . ' boot disk image for ${channel}',
                        'repodir'      => '${repodir}',
                        'channel'      => '${channel}',
                        'deviceclass'  => $deviceclass,
                        'imagesize'    => '3G',
                        'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}-' . $deviceclass . '_${tstamp}.img',
                        'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}-' . $deviceclass . '_LATEST.img'
                    ),
                    'vbox' => new Macrobuild::CompositeTasks::Sequential(
                        'tasks' => [
                            new UBOS::Macrobuild::BasicTasks::CreateImage(
                                'name'         => 'Create ' . $deviceclass . ' boot disk image for ${channel} (VirtualBox)',
                                'repodir'      => '${repodir}',
                                'channel'      => '${channel}',
                                'deviceclass'  => "vbox-x86_64",
                                'imagesize'    => '3G',
                                'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-x86_64_${tstamp}.img',
                                'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-x86_64_LATEST.img' ),
                            new UBOS::Macrobuild::BasicTasks::ImagesToVmdk()
                        ]
                    ),
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'         => 'Create ' . $deviceclass . ' bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => 'container-x86_64',
                        'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-x86_64_${tstamp}.tardir',
                        'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-x86_64_LATEST.tardir',
                        'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-x86_64_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-x86_64_LATEST.tar'
                    ),
                    'ec2' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'         => 'Create ' . $deviceclass . ' EC2 image for ${channel}',
                        'repodir'      => '${repodir}',
                        'channel'      => '${channel}',
                        'deviceclass'  => 'ec2-instance',
                        'imagesize'    => '3G',
                        'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_ec2_${tstamp}.img',
                        'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_ec2_LATEST.img' ),
                    )
                },
                'joinTask' => new Macrobuild::CompositeTasks::MergeValues(
                        'name'         => 'Merge images list for ${channel}',
                        'keys'         => [ 'img', 'vbox', 'container', 'ec2' ]
                )
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images',
                'fields'      => [ 'images', 'vmdkimages', 'dirs', 'tarfiles' ] )
        ]
    );

    return $self;
}

1;




