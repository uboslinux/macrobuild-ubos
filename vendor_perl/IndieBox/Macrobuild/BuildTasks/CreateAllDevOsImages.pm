# 
# Creates all dev os images
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::CreateAllDevOsImages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use IndieBox::Macrobuild::ComplexTasks::CreateDevOsImages;
use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;

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
                    new IndieBox::Macrobuild::ComplexTasks::CreateDevOsImages(),
                    new Macrobuild::BasicTasks::Report(
                            'name'        => 'Report build activity for os',
                            'fields'      => [ 'bootimages', 'vmdkimages' ] )
            ]
    );

    return $self;
}

1;
