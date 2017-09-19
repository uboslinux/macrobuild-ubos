#
# Removes packages fetched from Arch and updates the package database
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch builddir repodir upconfigs db dbSignKey );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages;
use UBOS::Macrobuild::BasicTasks::Unstage;
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

                $task->appendTask( UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages->new(
                        'name'        => 'Removed packages fetched from Arch',
                        'arch'        => '${arch}',
                        'upconfigs'   => $upconfigs,
                        'downloaddir' => '${builddir}/dbs/' . $db . '/upc/${arch}' ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::Unstage->new(
                        'name'        => 'Unstage removed packages in local repository',
                        'stagedir'    => '${repodir}/${arch}/' . $db ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
                        'name'        => 'Update package database with removed packages',
                        'dbfile'      => '${repodir}/${arch}/' . $db . '/' . $db . '.db.tar.xz' ),
                        'dbSignKey'   => '${dbSignKey}' );

                return SUCCESS;
            }
    );

    return $self;
}

1;
