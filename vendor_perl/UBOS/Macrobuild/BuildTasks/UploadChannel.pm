# 
# Promotes uploads a locally staged channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::Upload;
use UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;

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
            new UBOS::Macrobuild::BasicTasks::Upload(
                'from'        => '${repodir}/${arch}',
                'to'          => '${uploadDest}/${arch}',
                'excludeGlob' => [ '*.img', '*.vmdk' ] ), # don't upload uncompressed images
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report upload activity',
                'fields'      => [ 'uploaded-to' ]
            )
        ]
    );

    return $self;
}

1;
