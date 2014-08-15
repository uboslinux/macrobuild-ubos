# 
# Creates and uploads all images
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::CreateAndUploadImages;

use base qw( MacrobCompositeTasksuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;
use IndieBox::Macrobuild::BasicTasks::Upload;
use IndieBox::Macrobuild::ComplexTasks::CreateImages;

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
            new IndieBox::Macrobuild::ComplexTasks::CreateImages(),
            new IndieBox::Macrobuild::BasicTasks::Upload(
                'from'        => '${imagedir}/${arch}/images',
                'to'          => 'buildmaster@depot.indiebox.net:/var/lib/cldstr-archdepot/a00000000000000000000000000000003/${arch}/images' ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for creating and uploading ${channel} images',
                'fields'      => [ 'bootimages', 'vmdkimages' ] )
        ]
    );

    return $self;
}

1;
