#
# Purges outdated images from a channel.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PurgeImages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::PurgeChannelImages;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my @places = qw( images compressed-images );

    foreach my $place ( @places ) {
        $self->addParallelTask(
                $place,
                UBOS::Macrobuild::BasicTasks::PurgeChannelImages->new(
                        'dir'    => '${repodir}/${channel}/${arch}/' . $place ));
    }
    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge image purge results',
            'keys' => \@places ));

    return $self;
}

1;
