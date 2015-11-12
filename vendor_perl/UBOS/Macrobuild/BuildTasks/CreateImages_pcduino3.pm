# 
# Creates all images for the pcduino3
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_pcduino3;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::CreateImage;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    my $deviceclass = 'pcduino3';

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
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'              => 'Create bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => 'container',
                        'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container_' . $deviceclass . '_${tstamp}',
                        'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container_' . $deviceclass . '_LATEST',
                        'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container_' . $deviceclass . '_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container_' . $deviceclass . '_LATEST.tar'
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
