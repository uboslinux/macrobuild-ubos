# 
# Purges outdated images from a channel.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PurgeImages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PurgeChannelImages;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    my $age        = 60*60*24*14; # Two weeks
    my $purgeTasks = {};

    $purgeTasks->{"purge-images"} = new UBOS::Macrobuild::BasicTasks::PurgeChannelImages(
            'dir' => '${repodir}/${arch}/images' );
    $purgeTasks->{"purge-uncompressed-images"} = new UBOS::Macrobuild::BasicTasks::PurgeChannelImages(
            'dir' => '${repodir}/${arch}/uncompressed-images' );
    
    my @purgeTaskNames = keys %$purgeTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $purgeTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge image purge results',
                    'keys'         => \@purgeTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report image purge activity',
                    'fields'      => [ 'purged', 'kept' ] )
            ]
        ));

    return $self;
}

1;
