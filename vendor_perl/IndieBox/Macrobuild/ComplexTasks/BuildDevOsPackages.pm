# 
# Builds os in dev, updates packages
#

use strict;
use warnings;

package IndieBox::Macrobuild::ComplexTasks::BuildDevOsPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( upconfigs usconfigs );

use IndieBox::Macrobuild::BasicTasks::BuildPackages;
use IndieBox::Macrobuild::BasicTasks::DownloadPackageDbs;
use IndieBox::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;
use IndieBox::Macrobuild::BasicTasks::FetchPackages;
use IndieBox::Macrobuild::BasicTasks::PullSources;
use IndieBox::Macrobuild::BasicTasks::Stage;
use IndieBox::Macrobuild::BasicTasks::UpdatePackageDatabase;
use IndieBox::Macrobuild::UpConfigs;
use IndieBox::Macrobuild::UsConfigs;
use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
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

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin( 
            'parallelTasks' => {
                'fetch-upstream-packages' => new Macrobuild::CompositeTasks::Sequential(
                    'tasks' => [
                        new IndieBox::Macrobuild::BasicTasks::DownloadPackageDbs(
                                'name'        => 'Download package database files from Arch',
                                'upconfigs'   => $self->{upconfigs},
                                'downloaddir' => '${builddir}/upc/${arch}' ),
                        new IndieBox::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir(
                                'name'        => 'Determining which packages changed in Arch',
                                'upconfigs'   => $self->{upconfigs},
                                'dir'         => '${builddir}/upc/${arch}' ),
                        new IndieBox::Macrobuild::BasicTasks::FetchPackages(
                                'name'        => 'Fetching packages downloaded from Arch for repository',
                                'downloaddir' => '${builddir}/upc/${arch}' ),
                        new IndieBox::Macrobuild::BasicTasks::Stage(
                                'name'        => 'Stage new packages in local repository',
                                'stagedir'    => '${repodir}/${arch}/os' ),
                    ]
                ),
                'build-indie-packages' => new Macrobuild::CompositeTasks::Sequential(
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
                                'stagedir'    => '${repodir}/${arch}/os' ),
                    ]                
                )
            },
            'joinTask' => new Macrobuild::CompositeTasks::Sequential(
                'tasks' => [
                    new Macrobuild::CompositeTasks::MergeValuesTask(
                            'name'         => 'Merge update lists from download and local build',
                            'keys'         => [ 'build-indie-packages', 'fetch-upstream-packages' ] ),
                    new IndieBox::Macrobuild::BasicTasks::UpdatePackageDatabase(
                            'name'         => 'Update package database with new packages',
                            'dbfile'       => '${repodir}/${arch}/os/os.db.tar.xz' )
                ]
            ));

    return $self;
}

1;
