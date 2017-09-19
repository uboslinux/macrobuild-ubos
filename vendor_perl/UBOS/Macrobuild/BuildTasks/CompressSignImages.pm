#
# Compresses images and signs them.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CompressSignImages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch repodir imageSignKey );

use Macrobuild::Task;
use Macrobuild::CompositeTasks::Sequential;
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

    $self->SUPER::new(
            %args,
            'setup' => sub {
                my $run  = shift;
                my $task = shift;

                $task->appendTask( UBOS::Macrobuild::BasicTasks::CompressFiles->new(
                        'name'           => 'Compressing to ${repodir}/${arch}/images',
                        'inDir'          => '${repodir}/${arch}/uncompressed-images',
                        'glob'           => '*.{img,vmdk,tar}',
                        'outDir'         => '${repodir}/${arch}/images',
                        'adjustSymlinks' => 1 ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::SignFiles->new(
                        'name'           => 'Signing images in to ${repodir}/${arch}/images',
                        'glob'           => '*.{img,vmdk,tar}.xz',
                        'dir'            => '${repodir}/${arch}/images',
                        'imageSignKey'   => '${imageSignKey}' ));

                return SUCCESS;
            } );

    return $self;
}

1;
