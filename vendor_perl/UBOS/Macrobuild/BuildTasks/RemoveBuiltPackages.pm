# 
# Removes packages we built that are marked to be removed
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RemoveBuiltPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages;
use UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages;
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

    my $localSourcesDir = $self->{_settings}->getVariable( 'localSourcesDir' );

    my $repoUsConfigs       = {};
    my $repoUpConfigs       = {};
    my $removePackagesTasks = {};
    my @dbs                 = UBOS::Macrobuild::Utils::determineDbs( 'dbs', %args );

    my @removePackagesTasksSequence = map { ( "remove-built-packages-$_" ) } @dbs;

    # create remove packages tasks
    foreach my $db ( @dbs ) {
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up', $localSourcesDir );

        $removePackagesTasks->{"remove-built-packages-$db"} = new UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages(
            'name'           => 'Remove built packages marked as such from ' . $db,
            'usconfigs'      => $repoUsConfigs->{$db},
            'db'             => UBOS::Macrobuild::Utils::shortDb( $db ) );
    }
    
    my @removePackagesTaskNames = keys %$removePackagesTasks;

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'                  => 'Remove packages from dbs ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ) . ', then merge update lists and report',
        'parallelTasks'         => $removePackagesTasks,
        'parallelTasksSequence' => \@removePackagesTasksSequence,
        'joinTask'              => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge update lists from dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'keys'         => \@removePackagesTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report remove package activity for dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'fields'      => [ 'removed-packages' ] )
            ]
        ));
    return $self;
}

1;
