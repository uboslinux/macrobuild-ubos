# 
# Creates all images for the Raspberry Pi.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAllImages_rpi;

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
    
    $self->SUPER::new( @args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::CreateImage(
                'name'         => 'Create boot disk image for ${channel}',
                'repodir'      => '${repodir}',
                'channel'      => '${channel}',
                'deviceclass'  => 'rpi',
                'imagesize'    => '3G',
                'image'        => '${imagesdir}/${arch}/images/ubos_${channel}_rpi_${tstamp}.img',
                'linkLatest'   => '${imagesdir}/${arch}/images/ubos_${channel}_rpi_LATEST.img'
            ),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images' ),
                'fields'      => [ 'bootimages' ] )
        ]
    );

    return $self;
}

1;
