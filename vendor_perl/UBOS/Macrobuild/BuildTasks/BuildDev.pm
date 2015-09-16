# 
# Builds the repositories in dev, updates packages
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BuildDev;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::BasicTasks::SetupMaven;
use UBOS::Macrobuild::ComplexTasks::BuildDevPackages;
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


    # only check overlap in UBOS, not arch-tools
    my $ubosRepoUpConfigs = {};
    my $ubosRepoUsConfigs = {};
    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $buildTasks    = {};
    my @dbs           = UBOS::Macrobuild::Utils::determineDbs( 'dbs',     %args );
    my @archDbs       = UBOS::Macrobuild::Utils::determineDbs( 'archDbs', %args );

    my @buildTasksSequence = ();
    push @buildTasksSequence, map { "build-$_" } @dbs;
    push @buildTasksSequence, map { "build-$_" } @archDbs;

    # create build tasks
    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );
        $ubosRepoUpConfigs->{$db} = $repoUpConfigs->{$db};
        $ubosRepoUsConfigs->{$db} = $repoUsConfigs->{$db};

        $buildTasks->{"build-$db"} = new UBOS::Macrobuild::ComplexTasks::BuildDevPackages(
            'name'           => 'Build ' . $db . ' packages',
            'upconfigs'      => $repoUpConfigs->{$db},
            'usconfigs'      => $repoUsConfigs->{$db},
            'db'             => UBOS::Macrobuild::Utils::shortDb( $db ),
            'm2settingsfile' => $m2BuildDir . '/settings.xml',
            'm2repository'   => $m2BuildDir . '/repository' );
    }
    foreach my $db ( @archDbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', '${localSourcesDir}' );

        $buildTasks->{"build-$db"} = new UBOS::Macrobuild::ComplexTasks::BuildDevPackages(
            'name'       => 'Build ' . $db . ' packages',
            'upconfigs'  => $repoUpConfigs->{$db},
            'usconfigs'  => $repoUsConfigs->{$db},
            'db'         => UBOS::Macrobuild::Utils::shortDb( $db ));
    }
    
    # create check tasks
    my @checkTasks = (
        new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
            'repoUpConfigs' => $ubosRepoUpConfigs,
            'repoUsConfigs' => $ubosRepoUsConfigs ),
    );
    foreach my $keyType ( 'packageSignKey', 'dbSignKey', 'imageSignKey' ) {
        my $keyId = $self->{_settings}->getVariable( $keyType );
        if( $keyId ) {
            push @checkTasks, new UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey( 'keyId' => $keyId );
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
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge update lists from dev dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dev dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'fields'      => [ 'updated-packages' ] )
            ]
        ));
    return $self;
}

1;
