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
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    my @deviceclasses = qw( espressobin container );

    $self->SUPER::new(
            %args,
            'setup' => sub {
                my $run  = shift;
                my $task = shift;

                foreach my $deviceclass ( @deviceclasses ) {
                    $task->addParallelTask(
                            $deviceclass,
                            UBOS::Macrobuild::BasicTasks::CreateImage->new(
                                    'name'        => 'Create ${arch} ${deviceclass} boot disk image for ${channel}',
                                    'channel'     => '${channel}',
                                    'depotRoot'   => '${depotRoot}',
                                    'deviceclass' => $deviceclass,
                                    'imagesize'   => '3G',
                                    'image'       => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_${tstamp}.img',
                                    'linkLatest'  => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_LATEST.img',
                                    'repodir'     => '${repodir}' ));
                }

                $self->setJoinTask( Macrobuild::CompositeTasks::MergeValues->new(
                        'name' => 'Merge images list for ${channel}',
                        'keys' => \@deviceclasses ));

                return SUCCESS;
            } );

    return $self;
}

1;




