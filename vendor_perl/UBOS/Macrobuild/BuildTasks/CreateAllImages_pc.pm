# 
# Creates all images for the PC
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAllImages_pc;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CreateImage;
use UBOS::Macrobuild::BasicTasks::ImageToVmdk;

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
            new Macrobuild::CompositeTasks::SplitJoin( 
                'parallelTasks' => {
                    'img' => new UBOS::Macrobuild::BasicTasks::CreateImage(
                        'name'         => 'Create boot disk image for ${channel}',
                        'repodir'      => '${repodir}',
                        'channel'      => '${channel}',
                        'deviceclass'  => 'pc',
                        'imagesize'    => '3G',
                        'image'        => '${imagesdir}/${arch}/images/ubos_${channel}_pc_x86_64_${tstamp}.img',
                        'linkLatest'   => '${imagesdir}/${arch}/images/ubos_${channel}_pc_x86_64_LATEST.img'
                    ),
                    'vbox.img' => new Macrobuild::CompositeTasks::Sequential(
                        'tasks' => [
                            new UBOS::Macrobuild::BasicTasks::CreateImage(
                                'name'         => 'Create boot disk image for ${channel} for VirtualBox',
                                'repodir'      => '${repodir}',
                                'channel'      => '${channel}',
                                'deviceclass'  => 'vbox-pc',
                                'imagesize'    => '3G',
                                'image'        => '${imagesdir}/${arch}/images/ubos_${channel}_vbox-pc_x86_64_${tstamp}.img',
                                'linkLatest'   => '${imagesdir}/${arch}/images/ubos_${channel}_vbox-pc_x86_64_LATEST.img' ),
                            new UBOS::Macrobuild::BasicTasks::ImagesToVmdk()
                        ]
                    )
                },
                'joinTask' => new Macrobuild::CompositeTasks::MergeValuesTask(
                        'name'         => 'Merge images list for ${channel}',
                        'keys'         => [ 'img', 'vbox.img' ]
                )
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} images',
                'fields'      => [ 'images', 'vmdkimages' ] )
        ]
    );

    return $self;
}

1;




