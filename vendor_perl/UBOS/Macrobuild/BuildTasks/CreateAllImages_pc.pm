# 
# Creates all images for the PC
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAllImages_pc;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
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
    
    my $deviceClass = 'pc';

    $self->SUPER::new( %args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin( 
                'parallelTasks' => {
                    'img' => new UBOS::Macrobuild::BasicTasks::CreateImage(
                        'name'         => 'Create boot disk image for ${channel}',
                        'repodir'      => '${repodir}',
                        'channel'      => '${channel}',
                        'deviceclass'  => $deviceClass,
                        'imagesize'    => '3G',
                        'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_' . $deviceClass . '_${tstamp}.img',
                        'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_' . $deviceClass . '_LATEST.img'
                    ),
                    'vbox.img' => new Macrobuild::CompositeTasks::Sequential(
                        'tasks' => [
                            new UBOS::Macrobuild::BasicTasks::CreateImage(
                                'name'         => 'Create boot disk image for ${channel} for VirtualBox',
                                'repodir'      => '${repodir}',
                                'channel'      => '${channel}',
                                'deviceclass'  => "vbox-$deviceClass",
                                'imagesize'    => '3G',
                                'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-' . $deviceClass . '_${tstamp}.img',
                                'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-' . $deviceClass . '_LATEST.img' ),
                            new UBOS::Macrobuild::BasicTasks::ImagesToVmdk()
                        ]
                    ),
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'              => 'Create bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => $deviceClass,
                        'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceClass . '_${tstamp}.tardir',
                        'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceClass . '_LATEST',
                        'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceClass . '_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceClass . '_LATEST.tar'
                    )
                },
                'joinTask' => new Macrobuild::CompositeTasks::MergeValuesTask(
                        'name'         => 'Merge images list for ${channel}',
                        'keys'         => [ 'img', 'vbox.img', 'container' ]
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




