# 
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::RunWebAppTests;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use IndieBox::Macrobuild::BasicTasks::RunWebAppTests;
use IndieBox::Macrobuild::UsConfigs;
use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/${repository}/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'stopOnError' => 0,
        'tasks' => [
            new IndieBox::Macrobuild::BasicTasks::RunWebAppTests(
                    'name'        => 'Run webapptests',
                    'usconfigs'   => $usConfigs,
                    'sourcedir'   => '${builddir}/ups' ),
            new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report webapptest results',
                    'fields'      => [ 'tests-failed' ] ) # no need to hear about the tests that passed
        ]
    );

    return $self;
}

1;
