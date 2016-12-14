# 
# Removes packages and updates the package database
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::RemoveUpdatePackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( upconfigs db );

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::RemovePackages;
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
        'name' => 'Remove packages for db ' . $self->{db},
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages(
                    'name'        => 'Removed packages fetched from Arch',
                    'downloaddir' => '${builddir}/dbs/' . $db . '/upc/${arch}' ),
            new UBOS::Macrobuild::BasicTasks::Unstage(
                    'name'        => 'Unstage removed packages in local repository',
                    'stagedir'    => '${repodir}/${arch}/' . $db ),
            new UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase(
                    'name'        => 'Update package database with removed packages',
                    'dbfile'      => '${repodir}/${arch}/' . $db . '/' . $db . '.db.tar.xz' )
        ]
    );

    return $self;
}

1;
