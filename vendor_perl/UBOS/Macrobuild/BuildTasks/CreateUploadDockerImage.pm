# 
# Creates and uploads an UBOS image to Docker
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateUploadDockerImage;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CreateDockerImage;
use UBOS::Macrobuild::BasicTasks::UploadDockerImage;

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
            new UBOS::Macrobuild::BasicTasks::CreateDockerImage(
                'image'      => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-pc_LATEST.tar',
                'dockerName' => 'ubos/ubos-${channel}' ),

            new UBOS::Macrobuild::BasicTasks::UploadDockerImage(),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report create and upload to Docker activity',
                'fields'      => [ 'pushedImageIds' ]
            )
        ]
    );

    return $self;
}

1;

