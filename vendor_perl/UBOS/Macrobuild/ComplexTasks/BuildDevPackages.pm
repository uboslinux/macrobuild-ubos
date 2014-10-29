# 
# Builds dev, updates packages
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::BuildDevPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( upconfigs usconfigs db );

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::BuildPackages;
use UBOS::Macrobuild::BasicTasks::DownloadPackageDbs;
use UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;
use UBOS::Macrobuild::BasicTasks::FetchPackages;
use UBOS::Macrobuild::BasicTasks::PullSources;
use UBOS::Macrobuild::BasicTasks::Stage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;
use UBOS::Macrobuild::UpConfigs;
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

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
            'name' => 'Fetch upstream packages, build UBOS packages, then merge and update package database',
            'parallelTasks' => {
                'fetch-upstream-packages' => new Macrobuild::CompositeTasks::Sequential(
                    'name' => 'Fetch upstream packages for db ' . $self->{db},
                    'tasks' => [
                        new UBOS::Macrobuild::BasicTasks::DownloadPackageDbs(
                                'name'        => 'Download package database files from Arch',
                                'upconfigs'   => $self->{upconfigs},
                                'downloaddir' => '${builddir}/upc/${arch}' ),
                        new UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir(
                                'name'        => 'Determining which packages changed in Arch',
                                'upconfigs'   => $self->{upconfigs},
                                'dir'         => '${builddir}/upc/${arch}' ),
                        new UBOS::Macrobuild::BasicTasks::FetchPackages(
                                'name'        => 'Fetching packages downloaded from Arch',
                                'downloaddir' => '${builddir}/upc/${arch}' ),
                        new UBOS::Macrobuild::BasicTasks::Stage(
                                'name'        => 'Stage new packages in local repository',
                                'stagedir'    => '${repodir}/${arch}/' . $self->{db} ),
                    ]
                ),
                'build-ubos-packages' => new Macrobuild::CompositeTasks::Sequential(
                    'name'  => 'Build UBOS packages',
                    'tasks' => [
                        new UBOS::Macrobuild::BasicTasks::PullSources(
                                'name'        => 'Pull the sources that need to be built',
                                'usconfigs'   => $self->{usconfigs},
                                'sourcedir'   => '${builddir}/ups'  ),
                        new UBOS::Macrobuild::BasicTasks::BuildPackages(
                                'name'        => 'Building packages locally',
                                'sourcedir'   => '${builddir}/ups',
                                'stopOnError' => 0 ),
                        new UBOS::Macrobuild::BasicTasks::Stage(
                                'name'        => 'Stage new packages in local repository',
                                'stagedir'    => '${repodir}/${arch}/' . $self->{db} ),
                    ]                
                )
            },
            'joinTask' => new Macrobuild::CompositeTasks::Sequential(
                'tasks' => [
                    new Macrobuild::CompositeTasks::MergeValuesTask(
                            'name'         => 'Merge update lists from download and local build',
                            'keys'         => [ 'build-ubos-packages', 'fetch-upstream-packages' ] ),
                    new UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase(
                            'name'         => 'Update package database with new packages',
                            'dbfile'       => '${repodir}/${arch}/' . $self->{db} . '/' . $self->{db} . '.db.tar.xz' )
                ]
            ));

    return $self;
}

1;
