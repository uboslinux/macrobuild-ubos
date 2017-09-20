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
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new(
            %args,
            'setup' => sub {
                my $run  = shift;
                my $task = shift;

                my $deviceclass = 'pc';
                $task->addParallelTask(
                        $deviceclass,
                        UBOS::Macrobuild::BasicTasks::CreateImage->new(
                                'name'        => 'Create ${arch} ${deviceclass} boot disk image for ${channel}',
                                'repodir'     => '${repodir}',
                                'depotRoot'   => '${depotRoot}',
                                'channel'     => '${channel}',
                                'deviceclass' => $deviceclass,
                                'imagesize'   => '3G',
                                'image'       => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_${tstamp}.img',
                                'linkLatest'  => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_LATEST.img' ));

                $deviceclass = 'vbox';
                $task->addParallelTask(
                        $deviceclass,
                        Macrobuild::CompositeTasks::Sequential->new(
                                'setup' => sub {
                                    my $run2  = shift;
                                    my $task2 = shift;

                                    $task2->appendTask( UBOS::Macrobuild::BasicTasks::CreateImage->new(
                                            'name'        => 'Create ${arch} ${deviceclass} boot disk image for ${channel}',
                                            'repodir'     => '${repodir}',
                                            'depotRoot'   => '${depotRoot}',
                                            'channel'     => '${channel}',
                                            'deviceclass' => $deviceclass,
                                            'imagesize'   => '3G',
                                            'image'       => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_${tstamp}.img',
                                            'linkLatest'  => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_LATEST.img' ));

                                    $task2->appendTask( UBOS::Macrobuild::BasicTasks::ImagesToVmdk->new());
                                } ));

                $deviceclass = 'container';
                $self->addParallelTask(
                        $deviceclass,
                        UBOS::Macrobuild::BasicTasks::CreateContainer->new(
                                'name'              => 'Create x86_64 bootable container for ${channel}',
                                'repodir'           => '${repodir}',
                                'depotRoot'         => '${depotRoot}',
                                'channel'           => '${channel}',
                                'deviceclass'       => $deviceclass,
                                'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_${tstamp}.tardir',
                                'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_LATEST.tardir',
                                'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_${tstamp}.tar',
                                'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_LATEST.tar' ));

                $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name' => 'Merge images list for ${channel}',
                        'keys' => [ 'pc', 'vbox', 'container' ] ));

                return SUCCESS;
            } );

    return $self;
}

1;




