# 
# Builds a repository in dev, updates packages
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildDev;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;
use IndieBox::Macrobuild::ComplexTasks::BuildDevPackages;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    my $upConfigs = IndieBox::Macrobuild::UpConfigs->allIn( '${configdir}/${repository}/up' );
    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/${repository}/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::ComplexTasks::BuildDevPackages(
                'upconfigs'   => $upConfigs,
                'usconfigs'   => $usConfigs,
                'repository'  => '${repository}' ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for ${repository} in dev',
                'fields'      => [ 'updated-packages' ] )
        ]
    );

    return $self;
}

1;
