# 
# Creates all images for the Raspberry Pi 2.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAllImages_rpi2;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CreateImage;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    my $deviceClass = 'rpi2';

    $self->SUPER::new( @args );

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
                        'image'        => '${repodir}/${arch}/images/ubos_${channel}_${deviceclass}_${tstamp}.img',
                        'linkLatest'   => '${repodir}/${arch}/images/ubos_${channel}_${deviceclass}_LATEST.img'
                    ),
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'              => 'Create bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => $deviceClass,
                        'dir'               => '${repodir}/${arch}/images/ubos_${channel}_container_${deviceclass}_${tstamp}',
                        'linkLatest-dir'    => '${repodir}/${arch}/images/ubos_${channel}_container_${deviceclass}_LATEST',
                        'tarfile'           => '${repodir}/${arch}/images/ubos_${channel}_container_${deviceclass}_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/images/ubos_${channel}_container_${deviceclass}_LATEST.tar'
                    )
                },
                'joinTask' => new Macrobuild::CompositeTasks::MergeValuesTask(
                        'name'         => 'Merge images list for ${channel}',
                        'keys'         => [ 'img', 'container' ]
                )
            ),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images',
                'fields'      => [ 'images', 'dirs', 'tarfiles' ] )
        ]
    );
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
                        'image'        => '${repodir}/${arch}/images/ubos_${channel}_${deviceClass}_${tstamp}.img',
                        'linkLatest'   => '${repodir}/${arch}/images/ubos_${channel}_${deviceClass}_LATEST.img'
                    ),
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'              => 'Create bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => 'pc',
                        'dir'               => '${repodir}/${arch}/images/ubos_${channel}_container_${deviceClass}_${tstamp}',
                        'linkLatest-dir'    => '${repodir}/${arch}/images/ubos_${channel}_container_${deviceClass}_LATEST',
                        'tarfile'           => '${repodir}/${arch}/images/ubos_${channel}_container_${deviceClass}_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/images/ubos_${channel}_container_${deviceClass}_LATEST.tar'
                    )
                },
                'joinTask' => new Macrobuild::CompositeTasks::MergeValuesTask(
                        'name'         => 'Merge images list for ${channel}',
                        'keys'         => [ 'img', 'container' ]
                )
            ),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images',
                'fields'      => [ 'images', 'dirs', 'tarfiles' ] )
        ]
    );

    return $self;
}

1;
