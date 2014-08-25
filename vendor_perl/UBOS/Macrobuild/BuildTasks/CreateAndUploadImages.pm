# 
# Creates and uploads all images
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAndUploadImages;

use base qw( MacrobCompositeTasksuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;
use UBOS::Macrobuild::BasicTasks::Upload;
use UBOS::Macrobuild::ComplexTasks::CreateImages;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    $self->{delegate} = new Macrobuild::ComplexTasks::Sequential(
        'tasks' => [
            new UBOS::Macrobuild::ComplexTasks::CreateImages(),
            new UBOS::Macrobuild::BasicTasks::Upload(
                'from'        => '${imagedir}/${arch}/images',
                'to'          => '${uploadDest}/${arch}/images' ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating and uploading ${channel} images',
                'fields'      => [ 'bootimages', 'vmdkimages' ] )
        ]
    );

    return $self;
}

1;