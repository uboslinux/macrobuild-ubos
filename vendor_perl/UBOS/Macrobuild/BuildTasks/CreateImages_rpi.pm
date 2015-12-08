# 
# Creates all images for the Raspberry Pi.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_rpi;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
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
    
    my $deviceclass = 'rpi';

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
                    'container' => new UBOS::Macrobuild::BasicTasks::CreateContainer(
                        'name'              => 'Create ' . $deviceclass . ' bootable container for ${channel}',
                        'repodir'           => '${repodir}',
                        'channel'           => '${channel}',
                        'deviceclass'       => 'container-armv6h',
                        'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-armv6h_${tstamp}.tardir',
                        'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-armv6h_LATEST.tardir',
                        'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-armv6h_${tstamp}.tar',
                        'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-armv6h_LATEST.tar'
                    )
                },
                'joinTask' => new Macrobuild::CompositeTasks::MergeValues(
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
