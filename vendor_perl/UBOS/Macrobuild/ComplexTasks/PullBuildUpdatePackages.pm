#
# Pulls packages, builds them, and updates the package database
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::PullBuildUpdatePackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch builddir repodir usconfigs db dbSignKey m2settingsfile m2repository );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::BuildPackages;
use UBOS::Macrobuild::BasicTasks::PullSources;
use UBOS::Macrobuild::BasicTasks::Stage;
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

    $self->appendTask( UBOS::Macrobuild::BasicTasks::PullSources->new(
            'name'           => 'Pull the sources that need to be built for db ' . $db,
            'usconfigs'      => $self->{usconfigs},
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups'  ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::BuildPackages->new(
            'name'           => 'Building packages locally for db ' . $self->{db},
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups',
            'stopOnError'    => 0,
            'm2settingsfile' => '${m2settingsfile}',
            'm2repository'   => '${m2repository}' ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
            'name'           => 'Stage new packages in local repository for db ' . $self->{db},
            'stagedir'       => '${repodir}/${channel}/${arch}/' . $db ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
            'name'          => 'Update package database with new packages',
            'dbfile'        => '${repodir}/${channel}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
            'dbSignKey'     => '${dbSignKey}' ));

    return $self;
}

1;
