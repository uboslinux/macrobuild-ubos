# 
# Creates images
#

use strict;
use warnings;

package IndieBox::Macrobuild::ComplexTasks::CreateImages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use IndieBox::Macrobuild::BasicTasks::BootImageToVmdk;
use IndieBox::Macrobuild::BasicTasks::CreateBootImage;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Logging;

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
            'img' => new IndieBox::Macrobuild::BasicTasks::CreateBootImage(
                'name'         => 'Create 1-partition boot disk image for ${channel}',
                'repodir'      => '${repodir}/${channel}',
                'channel'      => '${channel}',
                'image'        => '${imagedir}/${arch}/images/indiebox_${channel}_${arch}_${tstamp}-1part.img',
                'imagesize'    => '3G',
                'rootpartsize' => 'all',
                'fs'           => 'btrfs',
                'type'         => 'img',
                'linkLatest'   => '${imagedir}/${arch}/images/indiebox_${channel}_${arch}_LATEST-1part.img'
            ),
            'vbox.img' => new Macrobuild::CompositeTasks::Sequential(
                'tasks' => [
                    new IndieBox::Macrobuild::BasicTasks::CreateBootImage(
                        'name'         => 'Create 1-partition boot disk for ${channel} for VirtualBox',
                        'repodir'      => '${repodir}/${channel}',
                        'channel'      => '${channel}',
                        'image'        => '${imagedir}/${arch}/images/indiebox_${channel}_${arch}_${tstamp}-1part-vbox.img',
                        'imagesize'    => '3G',
                        'rootpartsize' => 'all',
                        'fs'           => 'btrfs',
                        'type'         => 'vbox.img',
                        'linkLatest'   => '${imagedir}/${arch}/images/indiebox_${channel}_${arch}_LATEST-1part-vbox.img' ),
                    new IndieBox::Macrobuild::BasicTasks::BootImageToVmdk()
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
