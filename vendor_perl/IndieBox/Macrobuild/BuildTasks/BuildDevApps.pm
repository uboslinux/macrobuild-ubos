# 
# Builds apps in dev, updates packages
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildDevApps;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use IndieBox::Macrobuild::ComplexTasks::BuildDevAppsPackages;
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

    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/apps/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::ComplexTasks::BuildDevAppsPackages(
                'usconfigs'   => $usConfigs ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for apps',
                'fields'      => [ 'updated-packages' ] )
        ]
    );

    return $self;
}

1;
