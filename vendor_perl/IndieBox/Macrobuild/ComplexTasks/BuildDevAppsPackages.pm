# 
# Builds apps in dev, updates packages
#

use strict;
use warnings;

package IndieBox::Macrobuild::ComplexTasks::BuildDevAppsPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( usconfigs );

use IndieBox::Macrobuild::BasicTasks::BuildPackages;
use IndieBox::Macrobuild::BasicTasks::PullSources;
use IndieBox::Macrobuild::BasicTasks::Stage;
use IndieBox::Macrobuild::BasicTasks::UpdatePackageDatabase;
use IndieBox::Macrobuild::UsConfigs;
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

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::BasicTasks::PullSources(
                    'name'        => 'Pull the sources that need to be built',
                    'usconfigs'   => $self->{usconfigs},
                    'sourcedir'   => '${builddir}/ups'  ),
            new IndieBox::Macrobuild::BasicTasks::BuildPackages(
                    'name'        => 'Building packages locally',
                    'sourcedir'   => '${builddir}/ups',
                    'stopOnError' => 0 ),
            new IndieBox::Macrobuild::BasicTasks::Stage(
                    'name'        => 'Stage new packages in local repository',
                    'stagedir'    => '${repodir}/${arch}/apps' ),
            new IndieBox::Macrobuild::BasicTasks::UpdatePackageDatabase(
                    'name'         => 'Update package database with new packages',
                    'dbfile'       => '${repodir}/${arch}/apps/apps.db.tar.xz' )
        ]
    );

    return $self;
}

1;


