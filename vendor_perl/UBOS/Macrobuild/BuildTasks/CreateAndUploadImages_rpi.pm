# 
# Creates and uploads the image for the Raspberry Pi. This uses the plural name
# to be consistent on all device types
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAndUploadImages_pc;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::Upload;
use UBOS::Macrobuild::BasicTasks::CreateBootImage_rpi;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::CreateBootImage_rpi(
                'name'         => 'Create boot disk image for ${channel}',
                'repodir'      => '${repodir}',
                'channel'      => '${channel}',
                'image'        => '${imagesdir}/${arch}/images/ubos_${channel}_${arch}_${tstamp}.img',
                'imagesize'    => '3G',
                'rootpartsize' => 'all',
                'fs'           => 'btrfs',
                'linkLatest'   => '${imagesdir}/${arch}/images/ubos_${channel}_${arch}_LATEST.img'
            ),

            new UBOS::Macrobuild::BasicTasks::Upload(
                'from'        => '${imagesdir}/${arch}/images',
                'to'          => '${uploadDest}/${arch}/images' ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating and uploading ${channel} images',
                'fields'      => [ 'bootimages', 'vmdkimages' ] )
        ]
    );

    return $self;
}

1;
