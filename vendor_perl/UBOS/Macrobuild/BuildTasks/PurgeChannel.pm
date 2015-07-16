# 
# Purges outdated files from a channel.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PurgeChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PurgeChannelImages;
use UBOS::Macrobuild::BasicTasks::PurgeChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    my @dbs = UBOS::Macrobuild::Utils::dbs();

    my $age        = 60*60*24*14; # Two weeks
    my $purgeTasks = {};

    foreach my $db ( @dbs ) {
        $purgeTasks->{"purge-$db"} = new UBOS::Macrobuild::BasicTasks::PurgeChannelRepository(
                'dir' => '${repodir}/${arch}/' . $db,
                'age' => $age );
    }
    $purgeTasks->{"purge-images"} = new UBOS::Macrobuild::BasicTasks::PurgeChannelImages(
            'dir' => '${repodir}/${arch}/images' );
    $purgeTasks->{"purge-uncompressed-images"} = new UBOS::Macrobuild::BasicTasks::PurgeChannelImages(
            'dir' => '${repodir}/${arch}/uncompressed-images' );
    
    my @purgeTaskNames = keys %$purgeTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $purgeTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge purge results from repositories: ' . join( ' ', @dbs ) . ' and images',
                    'keys'         => \@purgeTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report purge activity for repositories: ' . join( ' ', @dbs ) . ' and images',
                    'fields'      => [ 'purged', 'kept' ] )
            ]
        ));

    return $self;
}

1;
