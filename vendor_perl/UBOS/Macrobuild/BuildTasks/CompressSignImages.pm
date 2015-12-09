# 
# Compresses images and signs them.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CompressSignImages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CompressFiles;
use UBOS::Macrobuild::BasicTasks::SignFiles;

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
                'name'           => 'Compressing to ${repodir}/${arch}/images',
                'inDir'          => '${repodir}/${arch}/uncompressed-images',
                'glob'           => '*.{img,vmdk,tar}',
                'outDir'         => '${repodir}/${arch}/images',
                'adjustSymlinks' => 1
            ),
            new UBOS::Macrobuild::BasicTasks::SignFiles(
                'name'           => 'Signing images in to ${repodir}/${arch}/images',
                'glob'           => '*.{img,vmdk,tar}.xz',
                'dir'            => '${repodir}/${arch}/images'
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report for compressing and signing images',
                'fields'      => [ 'files' ] )
        ]
    );

    return $self;
}

1;
