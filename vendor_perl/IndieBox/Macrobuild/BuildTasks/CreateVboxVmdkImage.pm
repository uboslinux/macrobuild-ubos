# 
# Creates the virtualbox vmdk image
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::CreateVboxVmdkImage;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
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
                'name'         => 'Create 1-partition boot disk for VirtualBox',
                'repodir'      => '${repodir}/${channel}',
                'channel'      => '${channel}',
                'image'        => '${imagedir}/${arch}/images/indiebox_${channel}_${arch}_${tstamp}-1part-vbox.img',
                'imagesize'    => '3G',
                'rootpartsize' => 'all',
                'fs'           => 'btrfs',
                'type'         => 'vbox.img',
                'linkLatest'   => '${imagedir}/${arch}/images/indiebox_${channel}_${arch}_LATEST-1part-vbox.img' ),
            new IndieBox::Macrobuild::BasicTasks::BootImageToVmdk(),
            new Macrobuild::BasicTasks::Report(
                'name'         => 'Report build activity for creating ${channel} virtualbox vmdk image',
                'fields'       => [ 'bootimages', 'vmdkimages' ] )
        ]
    );

    return $self;
}

1;
