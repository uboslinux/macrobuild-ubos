# 
# Compresses images
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CompressImages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CompressFiles;

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
            new UBOS::Macrobuild::BasicTasks::CompressFiles(
                'inDir'          => '${repodir}/${arch}/uncompressed-images',
                'glob'           => '*.{img,vmdk,tar}',
                'outDir'         => '${repodir}/${arch}/images',
                'adjustSymlinks' => 1
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report for compressing images',
                'fields'      => [ 'files' ] )
        ]
    );

    return $self;
}

1;
