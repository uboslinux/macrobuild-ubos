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

    my $repoUsConfigs = {};
    my @taskNames     = ();

    # create build tasks
    foreach my $db ( @$dbs ) {
        my $shortDb      = UBOS::Macrobuild::Utils::shortDb( $db );
        my $usConfigsObj = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );
        my $usConfigs    = $usConfigsObj->configs( $self );

        foreach my $usConfigName ( sort keys %$usConfigs ) {
            my $usConfig = $usConfigs->{$usConfigName};

            my $runTaskName = "run-automated-tests-$shortDb-$usConfigName";
            push @taskNames, $runTaskName;

            $self->addParallelTask(
                    $runTaskName,
                    UBOS::Macrobuild::BasicTasks::RunContainerWebAppTests->new(
                            'name'         => 'Run webapptests in ' . $shortDb . ' - ' . $usConfigName,
                            'usconfig'     => $usConfig,
                            'scaffold'     => '${scaffold}', # allows us to filter out directory parameter if not container, for example
                            'config'       => '${testconfig}',
                            'directory'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${arch}-container_LATEST.tardir',
                            'sourcedir'    => '${builddir}/dbs/' . $shortDb . '/ups' ));
        }
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
