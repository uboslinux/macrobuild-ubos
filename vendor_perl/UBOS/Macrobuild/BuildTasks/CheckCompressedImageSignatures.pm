# 
# Check that all compressed images in a channel have
# corresponding signature files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckCompressedImageSignatures;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckSignatures;

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
            new UBOS::Macrobuild::BasicTasks::CheckSignatures(
                'name'  => 'Check signatures for compressed images',
                'dir'   => '${repodir}/${arch}/images',
                'glob'  => '*.tar.xz' ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report check compressed image signatures from ${channel}',
                'fields'      => [ 'unsigned' ] )
        ]
    );

    return $self;
}

1;
