# 
# Fetches packages from Arch and updates the package database
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( upconfigs db );

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::DownloadPackageDbs;
use UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;
use UBOS::Macrobuild::BasicTasks::FetchPackages;
use UBOS::Macrobuild::BasicTasks::Stage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;
use UBOS::Macrobuild::UpConfigs;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    my $db = $self->{db};

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'name' => 'Fetch upstream packages for db ' . $self->{db},
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::DownloadPackageDbs(
                    'name'        => 'Download package database files from Arch',
                    'upconfigs'   => $self->{upconfigs},
                    'downloaddir' => '${builddir}/dbs/' . $db . '/upc/${arch}' ),
            new UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir(
                    'name'        => 'Determining which packages changed in Arch',
                    'upconfigs'   => $self->{upconfigs},
                    'dir'         => '${builddir}/dbs/' . $db . '/upc/${arch}' ),
            new UBOS::Macrobuild::BasicTasks::FetchPackages(
                    'name'        => 'Fetching packages downloaded from Arch',
                    'downloaddir' => '${builddir}/dbs/' . $db . '/upc/${arch}' ),
            new UBOS::Macrobuild::BasicTasks::Stage(
                    'name'        => 'Stage new packages in local repository',
                    'stagedir'    => '${repodir}/${arch}/' . $db ),
            new UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase(
                    'name'         => 'Update package database with new packages',
                    'dbfile'       => '${repodir}/${arch}/' . $db . '/' . $db . '.db.tar.xz' )
        ]
    );

    return $self;
}

1;
