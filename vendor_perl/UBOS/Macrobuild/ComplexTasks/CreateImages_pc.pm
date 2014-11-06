# 
# Creates images
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::CreateImages_pc;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::BootImageToVmdk;
use UBOS::Macrobuild::BasicTasks::CreateBootImage_pc;
use UBOS::Macrobuild::BasicTasks::CreateBootImage_pc_vbox;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin( 
        'parallelTasks' => {
            'img' => new UBOS::Macrobuild::BasicTasks::CreateBootImage_pc(
                'name'         => 'Create 1-partition boot disk image for ${channel}',
                'repodir'      => '${repodir}',
                'channel'      => '${channel}',
                'image'        => '${imagesdir}/${arch}/images/ubos_${channel}_${arch}_${tstamp}.img',
                'imagesize'    => '3G',
                'rootpartsize' => 'all',
                'fs'           => 'btrfs',
                'linkLatest'   => '${imagesdir}/${arch}/images/ubos_${channel}_${arch}_LATEST.img'
            ),
            'vbox.img' => new Macrobuild::CompositeTasks::Sequential(
                'tasks' => [
                    new UBOS::Macrobuild::BasicTasks::CreateBootImage_pc_vbox(
                        'name'         => 'Create 1-partition boot disk for ${channel} for VirtualBox',
                        'repodir'      => '${repodir}',
                        'channel'      => '${channel}',
                        'image'        => '${imagesdir}/${arch}/images/ubos_${channel}_${arch}_${tstamp}-vbox.img',
                        'imagesize'    => '3G',
                        'rootpartsize' => 'all',
                        'fs'           => 'btrfs',
                        'linkLatest'   => '${imagesdir}/${arch}/images/ubos_${channel}_${arch}_LATEST-vbox.img' ),
                    new UBOS::Macrobuild::BasicTasks::BootImageToVmdk()
                ]
            )
        },
        'joinTask' => new Macrobuild::CompositeTasks::MergeValuesTask(
                'name'         => 'Merge images list for ${channel}',
                'keys'         => [ 'img', 'vbox.img' ] )
    );

    return $self;
}

1;
