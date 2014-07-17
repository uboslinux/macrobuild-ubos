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

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::BasicTasks::CreateBootImage(
                    'name'         => 'Create 1-partition boot disk',
                    'repodir'      => '${repodir}/${arch}/os',
                    'image'        => '${imagedir}/${arch}/images/indie-box_dev_${arch}_${tstamp}-1part.img',
                    'imagesize'    => '3G',
                    'rootpartsize' => 'all',
                    'fs'           => 'btrfs' ),
            new IndieBox::Macrobuild::BasicTasks::BootImageToVmdk()
        ] );
        
#        new Macrobuild::CompositeTasks::SplitJoin( 
#        'parallelTasks' => {
#            '2-partition-boot-disk' => new IndieBox::Macrobuild::BasicTasks::CreateBootImage(
#                    'name'         => 'Create 2-partition boot disk',
#                    'repodir'      => '${repodir}/${arch}/os',
#                    'image'        => '${imagedir}/${arch}/images/indie-box_dev_${arch}_${tstamp}-2part.img',
#                    'imagesize'    => '3G',
#                    'rootpartsize' => '1G',
#                    'fs'           => 'btrfs' ),
#            '1-partition-boot-disk' => new IndieBox::Macrobuild::BasicTasks::CreateBootImage(
#                    'name'         => 'Create 1-partition boot disk',
#                    'repodir'      => '${repodir}/${arch}/os',
#                    'image'        => '${imagedir}/${arch}/images/indie-box_dev_${arch}_${tstamp}-1part.img',
#                    'imagesize'    => '3G',
#                    'rootpartsize' => 'all',
#                    'fs'           => 'btrfs' )
#        },
#        'joinTask' => new Macrobuild::CompositeTasks::Sequential(
#            'tasks' => [
#                new Macrobuild::CompositeTasks::MergeValuesTask(
#                        'name'         => 'Merge images list',
#                        'keys'         => [ '2-partition-boot-disk', '1-partition-boot-disk' ] ),
#                new IndieBox::Macrobuild::BasicTasks::BootImageToVmdk()
#            ]
#        )
#    );

    return $self;
}

1;
