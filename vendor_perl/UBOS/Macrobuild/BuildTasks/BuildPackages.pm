# 
# Builds packages
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BuildPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::BasicTasks::SetupMaven;
use UBOS::Macrobuild::ComplexTasks::PullBuildUpdatePackages;
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

    my $m2BuildDir = '${builddir}/maven';
    my $localSourcesDir = $self->{_settings}->getVariable( 'localSourcesDir' );

    my $repoUsConfigs = {};
    my $buildTasks    = {};
    my @dbs           = UBOS::Macrobuild::Utils::determineDbs( 'dbs',     %args );

    my @buildTasksSequence = map { "build-$_" } @dbs;

    # create build tasks
    foreach my $db ( @dbs ) {
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        $buildTasks->{"build-$db"} = new UBOS::Macrobuild::ComplexTasks::PullBuildUpdatePackages(
            'name'           => 'Pull, build and update ' . $db . ' packages',
            'usconfigs'      => $repoUsConfigs->{$db},
            'db'             => UBOS::Macrobuild::Utils::shortDb( $db ),
            'm2settingsfile' => $m2BuildDir . '/settings.xml',
            'm2repository'   => $m2BuildDir . '/repository' );
    }
    
    # create check tasks
    my @checkTasks = (
        new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
            'repoUsConfigs' => $repoUsConfigs ),
    );
    foreach my $keyType ( 'packageSignKey', 'dbSignKey', 'imageSignKey' ) {
        my $keyId = $self->{_settings}->getVariable( $keyType );
        if( $keyId ) {
            $keyId = $self->{_settings}->replaceVariables( $keyId );
        }
        if( $keyId ) {
            push @checkTasks, new UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey(
                    'name'  => 'Checking we have private key of type ' . $keyType . ' for ' . $keyId,
                    'keyId' => $keyId );
        }
    }

    # create setup tasks
    my @setupTasks = (
        new UBOS::Macrobuild::BasicTasks::SetupMaven(
            'm2builddir' => $m2BuildDir
        )
    );

    my @buildTaskNames = keys %$buildTasks;

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'                  => 'Build dev dbs ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ) . ', then merge update lists and report',
        'splitTask'             => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                @checkTasks,
                @setupTasks ] ),
        'parallelTasks'         => $buildTasks,
        'parallelTasksSequence' => \@buildTasksSequence,
        'joinTask'              => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge update lists from dev dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dev dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'fields'      => [ 'added-package-files', 'removed-packages' ] )
            ]
        ));
    return $self;
}

1;
