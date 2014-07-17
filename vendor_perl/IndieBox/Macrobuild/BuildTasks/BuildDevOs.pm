# 
# Builds os in dev, updates packages
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildDevOs;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;
use IndieBox::Macrobuild::ComplexTasks::BuildDevOsPackages;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    my $upConfigs = IndieBox::Macrobuild::UpConfigs->allIn( '${configdir}/os/up' );
    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/os/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::ComplexTasks::BuildDevOsPackages(
                'upconfigs'   => $upConfigs,
                'usconfigs'   => $usConfigs ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for os',
                'fields'      => [ 'updated-packages' ] )
        ]
    );

    return $self;
}

1;
