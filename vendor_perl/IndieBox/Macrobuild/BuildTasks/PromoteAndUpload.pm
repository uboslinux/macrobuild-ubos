# 
# Promotes one channel to another and uploads.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildDev;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

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

    my @repos = (
        'os',
        'hl',
        'tools',
        'virt' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
        'tasks' => [
        ]
    );

    return $self;
}

1;
