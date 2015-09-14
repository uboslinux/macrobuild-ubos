# 
# Creates a single container image
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateContainerImage;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CreateContainer;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::CreateContainer(
                    'name'              => 'Create bootable container for ${channel}',
                    'repodir'           => '${repodir}',
                    'channel'           => '${channel}',
                    'deviceclass'       => '${deviceclass}',
                    'dir'               => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-${deviceclass}_${tstamp}.tardir',
                    'linkLatest-dir'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-${deviceclass}_LATEST.tardir',
                    'tarfile'           => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-${deviceclass}_${tstamp}.tar',
                    'linkLatest-tarfile'=> '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-${deviceclass}_LATEST.tar'
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating ${channel} container image',
                'fields'      => [ 'images', 'dirs', 'tarfiles' ] )
        ]
    );

    return $self;
}

1;
