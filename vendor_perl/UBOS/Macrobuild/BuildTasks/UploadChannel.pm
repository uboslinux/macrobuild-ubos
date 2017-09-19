#
# Uploads a locally staged channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch repodir uploadDest uploadInExclude );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::Upload;

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

                $task->setDelegate( UBOS::Macrobuild::BasicTasks::Upload->new(
                        'from'      => '${repodir}/${arch}',
                        'to'        => '${uploadDest}/${arch}',
                        'inexclude' => '${uploadInExclude}' ));

                return SUCCESS;
            });

    return $self;
}

1;
