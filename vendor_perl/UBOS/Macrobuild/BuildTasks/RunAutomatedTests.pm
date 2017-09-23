#
# Run the automated tests
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RunAutomatedTests;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch builddir db repodir testconfig scaffold );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::RunContainerWebAppTests;
use UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::UpConfigs;

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
    my @taskNames = ();

    # create tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        my $taskName = "run-automated-tests-$shortDb";
        push @taskNames, $taskName;

        $self->addParallelTask(
                $taskName,
                UBOS::Macrobuild::BasicTasks::RunAutomatedWebAppTests->new(
                        'name'      => 'Run automated web app tests in ' . $db,
                        'usconfigs' => $repoUsConfigs->{$shortDb},
                        'scaffold'  => '${scaffold}', # allows us to filter out directory parameter if not container, for example
                        'config'    => '${testconfig}',
                        'directory' => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-container_LATEST.tardir',
                        'sourcedir' => '${builddir}/dbs/' . $shortDb . '/ups' ));
    }

    my $task2 = Macrobuild::CompositeTasks::Sequential->new();
    $task2->appendTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge test results from dbs: ' . join( ' ', @$dbs ),
            'keys' => \@taskNames ));

    $task2->appendTask( UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults->new(
            'name' => 'Save app tests results' ));

    $self->setJoinTask( $task2 );

    return $self;
}

1;
