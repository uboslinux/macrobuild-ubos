# 
# Removes packages marked to be removed
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RemovePackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
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

    my $repoUsConfigs = {};
    my $buildTasks    = {};
    my @dbs           = UBOS::Macrobuild::Utils::determineDbs( 'dbs', %args );

    my @removePackagesTasksSequences = map { ( "remove-built-packages-$_", "remove-fetched-packages-$_" ) } @dbs;

    # create remove packages tasks
    foreach my $db ( @dbs ) {
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        $removePackagesTasks->{"remove-built-packages-$db"} = new UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages(
            'name'           => 'Remove built packages marked as such from ' . $db,
            'usconfigs'      => $repoUsConfigs->{$db},
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups',
            'db'             => UBOS::Macrobuild::Utils::shortDb( $db ) );

        $removePackagesTasks->{"remove-fetched-packages-$db"} = new UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages(
            'name'           => 'Remove fetched packages marked as such from ' . $db,
            'usconfigs'      => $repoUsConfigs->{$db},
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups',
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
