#
# Compresses images and signs them.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CompressSignImages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel repodir imageSignKey );

use Macrobuild::Task;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Macrobuild::BasicTasks::CompressFiles;
use UBOS::Macrobuild::BasicTasks::SignFiles;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::CompressFiles->new(
            'name'           => 'Compressing to ${repodir}/${channel}/${arch}/images',
            'inDir'          => '${repodir}/${channel}/${arch}/uncompressed-images',
            'glob'           => '*.{img,vmdk,tar}',
            'outDir'         => '${repodir}/${channel}/${arch}/images',
            'adjustSymlinks' => 1 ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::SignFiles->new(
            'name'           => 'Signing images in to ${repodir}/${channel}/${arch}/images',
            'glob'           => '*.{img,vmdk,tar}.xz',
            'dir'            => '${repodir}/${channel}/${arch}/images',
            'imageSignKey'   => '${imageSignKey}' ));

    return $self;
}

1;
