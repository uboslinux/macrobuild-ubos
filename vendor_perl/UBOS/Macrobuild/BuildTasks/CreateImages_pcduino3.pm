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
            new UBOS::Macrobuild::BasicTasks::CreateImage(
                'name'         => 'Create ' . $deviceclass . ' boot disk image for ${channel}',
                'repodir'      => '${repodir}',
                'channel'      => '${channel}',
                'deviceclass'  => $deviceclass,
                'imagesize'    => '3G',
                'image'        => '${repodir}/${arch}/uncompressed-images/ubos_${channel}-' . $deviceclass . '_${tstamp}.img',
                'linkLatest'   => '${repodir}/${arch}/uncompressed-images/ubos_${channel}-' . $deviceclass . '_LATEST.img'
            ),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images',
                'fields'      => [ 'images', 'dirs', 'tarfiles' ] )
        ]
    );

    return $self;
}

1;
