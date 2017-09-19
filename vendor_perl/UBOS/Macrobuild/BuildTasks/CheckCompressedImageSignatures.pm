#
# Check that all compressed images in a channel have
# corresponding signature files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckCompressedImageSignatures;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch repodir );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CheckSignatures;

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

                $task->setDelegate( UBOS::Macrobuild::BasicTasks::CheckSignatures->new(
                        'name'  => 'Check signatures for compressed images',
                        'dir'   => '${repodir}/${arch}/images',
                        'glob'  => '*.tar.xz' ));

                return SUCCESS;
            });

    return $self;
}

1;
