# 
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::Test;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use IndieBox::Macrobuild::BasicTasks::BuildPackages;
use IndieBox::Macrobuild::BasicTasks::PullSources;
use IndieBox::Macrobuild::BasicTasks::Stage;
use IndieBox::Macrobuild::UpConfigs;
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

    my $upConfigs = IndieBox::Macrobuild::UpConfigs->allIn( '${configdir}/${repository}/up' );
    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/${repository}/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
                        new IndieBox::Macrobuild::BasicTasks::PullSources(
                                'name'        => 'Pull the sources that need to be built',
                                'usconfigs'   => $usConfigs,
                                'sourcedir'   => '${builddir}/ups'  ),
                        new IndieBox::Macrobuild::BasicTasks::BuildPackages(
                                'name'        => 'Building packages locally',
                                'sourcedir'   => '${builddir}/ups',
                                'stopOnError' => 0 ),
#                        new IndieBox::Macrobuild::BasicTasks::Stage(
#                                'name'        => 'Stage new packages in local repository',
#                                'stagedir'    => '${repodir}/${arch}/${repository}' ),

#            new Macrobuild::BasicTasks::Report(
#                'name'        => 'Report build activity for ${repository} in dev',
#                'fields'      => [ 'updated-packages' ] )
        ]
    );

    return $self;
}

1;
