# 
# Uploads a locally staged channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::Upload;
use UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;

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
            new UBOS::Macrobuild::BasicTasks::Upload(
                'from'      => '${repodir}/${arch}',
                'to'        => '${uploadDest}/${arch}',
                'inexclude' => '${uploadInExclude}' ),

            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report upload activity',
                'fields'      => [ 'uploaded-to', 'uploaded-files' ]
            )
        ]
    );

    return $self;
}

1;
