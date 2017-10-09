#
# Builds packages
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BuildPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db localSourcesDir builddir repodir packageSignKey dbSignKey m2builddir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::BasicTasks::SetupMaven;
use UBOS::Macrobuild::ComplexTasks::PullBuildUpdatePackages;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $localSourcesDir = $self->getPropertyOrDefault( 'localSourcesDir', undef );

    my $dbs = $self->getProperty( 'db' );
    unless( ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUsConfigs  = {};
    my $repoUpConfigs  = {};
    my @buildTaskNames = ();

    # create build tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        my $buildTaskName = "build-$shortDb";
        push @buildTaskNames, $buildTaskName;

        $self->addParallelTask(
                $buildTaskName,
                UBOS::Macrobuild::ComplexTasks::PullBuildUpdatePackages->new(
                        'name'           => 'Pull, build and update ' . $db . ' packages',
                        'arch'           => '${arch}',
                        'builddir'       => '${builddir}',
                        'repodir'        => '${repodir}',
                        'usconfigs'      => $repoUsConfigs->{$shortDb},
                        'db'             => $shortDb,
                        'dbSignKey'      => '${dbSignKey}',
                        'm2settingsfile' => '${m2builddir}/settings.xml',
                        'm2repository'   => '${m2builddir}/repository' ));
    }

    my $splitTask = Macrobuild::CompositeTasks::Sequential->new();

    # create check tasks
    $splitTask->appendTask( UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps->new(
            'repoUpConfigs' => $repoUpConfigs,
            'repoUsConfigs' => $repoUsConfigs ));
    # no need to check for keys, we did this before

    # create setup tasks
    $splitTask->appendTask( UBOS::Macrobuild::BasicTasks::SetupMaven->new(
            'm2builddir' => '${m2builddir}' ));

    $self->setSplitTask( $splitTask );

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge update lists from dev dbs: ' . join( ' ', @$dbs ),
            'keys' => \@buildTaskNames ));

    return $self;
}

1;
