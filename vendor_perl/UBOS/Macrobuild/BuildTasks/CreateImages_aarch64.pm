#
# Creates all images for ARM aarch64
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_aarch64;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel depotRoot repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::CreateImage;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    my @deviceclasses = qw( espressobin );

    $self->SUPER::new( @args );

    foreach my $deviceclass ( @deviceclasses ) {
        $self->addParallelTask(
                $deviceclass,
                UBOS::Macrobuild::BasicTasks::CreateImage->new(
                        'name'        => 'Create ${arch} ' . $deviceclass . ' boot disk image for ${channel}',
                        'channel'     => '${channel}',
                        'depotRoot'   => '${depotRoot}',
                        'deviceclass' => $deviceclass,
                        'imagesize'   => '3G',
                        'image'       => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.img',
                        'linkLatest'  => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.img' ));
                        'repodir'     => '${repodir}' ));
    }

    $deviceclass = 'container';
    $self->addParallelTask(
            $deviceclass,
            UBOS::Macrobuild::BasicTasks::CreateContainer->new(
                    'name'              => 'Create ${arch} bootable container for ${channel}',
                    'repodir'           => '${repodir}',
                    'depotRoot'         => '${depotRoot}',
                    'channel'           => '${channel}',
                    'deviceclass'       => $deviceclass,
                    'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tardir',
                    'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.tardir',
                    'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tar',
                    'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.tar' ));

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge images list for ${channel}',
            'keys' => \( @deviceclasses, 'container' ) ));

    return $self;
}

1;




