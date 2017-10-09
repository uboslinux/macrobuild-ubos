#
# Creates all images for x86_64
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_x86_64;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel depotRoot repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::CreateImage;
use UBOS::Macrobuild::BasicTasks::ImagesToVmdk;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $deviceclass = 'pc';
    $self->addParallelTask(
            $deviceclass,
            UBOS::Macrobuild::BasicTasks::CreateImage->new(
                    'name'        => 'Create ${arch} ' . $deviceclass . ' boot disk image for ${channel}',
                    'arch'        => '${arch}',
                    'repodir'     => '${repodir}',
                    'depotRoot'   => '${depotRoot}',
                    'channel'     => '${channel}',
                    'deviceclass' => $deviceclass,
                    'imagesize'   => '3G',
                    'image'       => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.img',
                    'linkLatest'  => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.img' ));

    $deviceclass = 'vbox';
    my $vboxTask = Macrobuild::CompositeTasks::Sequential->new();

    $vboxTask->appendTask( UBOS::Macrobuild::BasicTasks::CreateImage->new(
            'name'        => 'Create ${arch} ' . $deviceclass . ' boot disk image for ${channel}',
            'arch'        => '${arch}',
            'repodir'     => '${repodir}',
            'depotRoot'   => '${depotRoot}',
            'channel'     => '${channel}',
            'deviceclass' => $deviceclass,
            'imagesize'   => '3G',
            'image'       => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.img',
            'linkLatest'  => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.img' ));

    $vboxTask->appendTask( UBOS::Macrobuild::BasicTasks::ImagesToVmdk->new());

    $self->addParallelTask(
            $deviceclass,
            $vboxTask );

    $deviceclass = 'container';
    $self->addParallelTask(
            $deviceclass,
            UBOS::Macrobuild::BasicTasks::CreateContainer->new(
                    'name'              => 'Create x86_64 bootable container for ${channel}',
                    'arch'              => '${arch}',
                    'repodir'           => '${repodir}',
                    'depotRoot'         => '${depotRoot}',
                    'channel'           => '${channel}',
                    'deviceclass'       => $deviceclass,
                    'dir'               => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tardir',
                    'linkLatest-dir'    => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.tardir',
                    'tarfile'           => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tar',
                    'linkLatest-tarfile'=> '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.tar' ));

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge images list for ${channel}',
            'keys' => [ 'pc', 'vbox', 'container' ] ));

    return $self;
}

1;




