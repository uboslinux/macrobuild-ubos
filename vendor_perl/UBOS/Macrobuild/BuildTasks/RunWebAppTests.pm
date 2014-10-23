# 
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RunWebAppTests;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::RunWebAppTests;
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

    my $usConfigs = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/${repository}/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'stopOnError' => 0,
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::RunWebAppTests(
                    'name'        => 'Run webapptests',
                    'usconfigs'   => $usConfigs,
                    'sourcedir'   => '${builddir}/ups' ),
            new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report webapptest results',
                    'fields'      => [ 'tests-sequence', 'tests-passed', 'tests-failed' ] )
        ]
    );

    return $self;
}

1;
