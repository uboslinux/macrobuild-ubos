# 
# Creates dev images
#

use strict;
use warnings;

package IndieBox::Macrobuild::ComplexTasks::CreateDevOsImages;

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
                'name'         => 'Create 1-partition boot disk image',
                'repodir'      => '${repodir}',
                'image'        => '${imagedir}/${arch}/images/indiebox_dev_${arch}_${tstamp}-1part.img',
                'imagesize'    => '3G',
                'rootpartsize' => 'all',
                'fs'           => 'btrfs',
                'type'         => 'img',
                'linkLatest'   => '${imagedir}/${arch}/images/indiebox_dev_${arch}_LATEST-1part-vbox.img'
            ),
            'vbox.img' => new Macrobuild::CompositeTasks::Sequential(
                'tasks' => [
                    new IndieBox::Macrobuild::BasicTasks::CreateBootImage(
                        'name'         => 'Create 1-partition boot disk for VirtualBox',
                        'repodir'      => '${repodir}',
                        'image'        => '${imagedir}/${arch}/images/indiebox_dev_${arch}_${tstamp}-1part-vbox.img',
                        'imagesize'    => '3G',
                        'rootpartsize' => 'all',
                        'fs'           => 'btrfs',
                        'type'         => 'vbox.img',
                        'linkLatest'   => '${imagedir}/${arch}/images/indiebox_dev_${arch}_LATEST-1part-vbox.img' ),
                    new IndieBox::Macrobuild::BasicTasks::BootImageToVmdk()
                ]
            )
        },
        'joinTask' => new Macrobuild::CompositeTasks::MergeValuesTask(
                'name'         => 'Merge images list',
                'keys'         => [ 'img', 'vbox.img' ] )
    );

    return $self;
}

1;
