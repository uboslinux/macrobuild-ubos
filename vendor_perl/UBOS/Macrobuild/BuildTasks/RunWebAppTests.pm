# 
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RunWebAppTests;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::RunWebAppTests;
use UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults;
use UBOS::Macrobuild::UsConfigs;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    my @dbs = UBOS::Macrobuild::Utils::determineDbs( 'dbs', %args );
    my $localSourcesDir = $self->{_settings}->getVariable( 'localSourcesDir' );

    my %tasks = ();
    foreach my $db ( @dbs ) {
        my $usConfigsObj = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );
        my $usConfigs    = $usConfigsObj->configs( $self->{_settings} );

        foreach my $repoName ( keys %$usConfigs ) {
            my $usConfig = $usConfigs->{$repoName}; 

            $tasks{$repoName} = new UBOS::Macrobuild::BasicTasks::RunWebAppTests(
                    'name'         => 'Run webapptests in ' . $db . ' - ' . $repoName,
                    'usconfig'     => $usConfig,
                    'scaffold'     => '${scaffold}', # allows us to filter out 'directory parameter if not container, for example
                    'config'       => '${testconfig}',
                    'directory'    => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_container-${arch}_LATEST.tardir',
                    'vmdktemplate' => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_vbox-${arch}_LATEST.vmdk',
                    'sourcedir'    => '${builddir}/dbs/' . UBOS::Macrobuild::Utils::shortDb( $db ) . '/ups' ),
        }
    }

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'stopOnError'   => 0,
        'parallelTasks' => \%tasks,
        'joinTask'      => new Macrobuild::CompositeTasks::SplitJoin(
            'splitTask' => new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge test results from dbs: ' . join( ' ', @dbs ),
                    'keys'         => [ keys %tasks ]
            ),
            'parallelTasks' => {
                    'save-results' => new UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults(
                            'name'        => 'Save app tests results' ),
                    'report' => new Macrobuild::BasicTasks::Report(
                            'name'        => 'Report webapptest results',
                            'fields'      => [ 'tests-sequence', 'tests-passed', 'tests-failed' ] )
            }
        )
    );

    return $self;
}

1;
