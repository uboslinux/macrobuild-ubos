#
# Fetches packages from Arch and updates the package database
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel builddir repodir upconfigs db dbSignKey );

use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::DownloadPackageDbs;
use UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;
use UBOS::Macrobuild::BasicTasks::FetchPackages;
use UBOS::Macrobuild::BasicTasks::Stage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new(
            %args,
            'setup' => sub {
                my $run  = shift;
                my $task = shift;

                my $db        = $run->getProperty( 'db' );
                my $upconfigs = $run->getProperty( 'upconfigs' );

                $task->appendTask( UBOS::Macrobuild::BasicTasks::DownloadPackageDbs->new(
                        'name'        => 'Download package database files from Arch',
                        'upconfigs'   => $upconfigs,
                        'downloaddir' => '${builddir}/dbs/' . $db . '/upc/${arch}' ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir->new(
                        'name'        => 'Determining which packages changed in Arch',
                        'upconfigs'   => $upconfigs,
                        'dir'         => '${builddir}/dbs/' . $db . '/upc/${arch}',
                        'channel'     => '${channel}',
                        'arch'        => '${arch}' ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::FetchPackages->new(
                        'name'        => 'Fetching packages downloaded from Arch',
                        'downloaddir' => '${builddir}/dbs/' . $db . '/upc/${arch}' ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
                        'name'        => 'Stage new packages in local repository',
                        'stagedir'    => '${repodir}/${arch}/' . $db ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
                        'name'        => 'Update package database with new packages',
                        'dbfile'      => '${repodir}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
                        'dbSignKey'   => '${dbSignKey}' ));

                return SUCCESS;
            }
    );

    return $self;
}

1;
