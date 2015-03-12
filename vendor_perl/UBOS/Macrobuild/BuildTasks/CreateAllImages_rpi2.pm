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
    
    $self->SUPER::new( @args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::CreateImage(
                'name'         => 'Create boot disk image for ${channel}',
                'repodir'      => '${repodir}',
                'channel'      => '${channel}',
                'deviceclass'  => 'rpi2',
                'imagesize'    => '3G',
                'image'        => '${repodir}/${arch}/images/ubos_${channel}_rpi2_${tstamp}.img',
                'linkLatest'   => '${repodir}/${arch}/images/ubos_${channel}_rpi2_LATEST.img'
            ),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images',
                'fields'      => [ 'bootimages' ] )
        ]
    );

    return $self;
}

1;
