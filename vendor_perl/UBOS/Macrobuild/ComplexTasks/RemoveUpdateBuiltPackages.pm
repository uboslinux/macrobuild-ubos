#
# Removes packages we built and updates the package database
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch builddir repodir usconfigs db dbSignKey );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::RemoveBuiltPackages;
use UBOS::Macrobuild::BasicTasks::Unstage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $db = $self->getProperty( 'db' );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::RemoveBuiltPackages->new(
            'name'        => 'Removed built packages',
            'arch'        => '${arch}',
            'usconfigs'   => $self->{usconfigs},
            'sourcedir'   => '${builddir}/dbs/' . $db . '/ups'  ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::Unstage->new(
            'name'        => 'Unstage removed packages in local repository',
            'stagedir'    => '${repodir}/${arch}/' . $db ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
            'name'        => 'Update package database with removed packages',
            'dbfile'      => '${repodir}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
            'dbSignKey'   => '${dbSignKey}' ));

    return $self;
}

1;
