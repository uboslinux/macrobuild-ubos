# 
# Purges outdated packages from a channel.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PurgeChannelPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PurgeChannelPackages;
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

    my @dbs           = UBOS::Macrobuild::Utils::determineDbs( 'dbs',     %args );
    my @archDbs       = UBOS::Macrobuild::Utils::determineDbs( 'archDbs', %args );

    @dbs = ( @dbs, @archDbs );

    foreach my $db ( @dbs ) {
        $purgeTasks->{"purge-$db"} = new UBOS::Macrobuild::BasicTasks::PurgeChannelPackages(
                'name' => 'Purge channel packages ' . $db,
                'dir'  => '${repodir}/${arch}/' . UBOS::Macrobuild::Utils::shortDb( $db ),
                'age'  => $age );
    }
    
    my @purgeTaskNames = keys %$purgeTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $purgeTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
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
