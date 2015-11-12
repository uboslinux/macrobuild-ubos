# 
# Creates all images for the PC
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_pc;

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
    
    my $deviceclass = 'pc';

    $self->SUPER::new( %args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin( 
                'parallelTasks' => {
                    'img' => new UBOS::Macrobuild::BasicTasks::CreateImage(
                        'name'         => 'Create boot disk image for ${channel}',
                        'repodir'      => '${repodir}',
                        'channel'      => '${channel}',
                        'deviceclass'  => $deviceclass,
                        'imagesize'    => '3G',
                        'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_' . $deviceclass . '_${tstamp}.img',
                        'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_' . $deviceclass . '_LATEST.img'
                    ),
                    'vbox.img' => new Macrobuild::CompositeTasks::Sequential(
                        'tasks' => [
                            new UBOS::Macrobuild::BasicTasks::CreateImage(
                                'name'         => 'Create boot disk image for ${channel} for VirtualBox',
                                'repodir'      => '${repodir}',
                                'channel'      => '${channel}',
                                'deviceclass'  => "vbox-$deviceclass",
                                'imagesize'    => '3G',
                                'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-' . $deviceclass . '_${tstamp}.img',
                                'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-' . $deviceclass . '_LATEST.img' ),
                            new UBOS::Macrobuild::BasicTasks::ImagesToVmdk()
                        ]
                    ),
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'              => 'Create bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => 'container-x86_64',
                        'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceclass . '_${tstamp}.tardir',
                        'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceclass . '_LATEST.tardir',
                        'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceclass . '_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-' . $deviceclass . '_LATEST.tar'
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




