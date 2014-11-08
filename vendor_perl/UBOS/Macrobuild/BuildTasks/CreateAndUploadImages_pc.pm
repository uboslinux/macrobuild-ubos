# 
# Creates and uploads all images for the PC
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateAndUploadImages_pc;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::Upload;
use UBOS::Macrobuild::ComplexTasks::CreateImages_pc;

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
            new UBOS::Macrobuild::ComplexTasks::CreateImages_pc(),
            new UBOS::Macrobuild::BasicTasks::Upload(
                'from'        => '${imagesdir}/${arch}/images',
                'to'          => '${uploadDest}/${arch}/images' ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating and uploading ${channel} images',
                'fields'      => [ 'bootimages', 'vmdkimages' ] )
        ]
    );

    return $self;
}

1;
