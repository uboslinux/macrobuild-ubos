# 
# Builds packages in dev
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::BuildDevPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( usconfigs db m2settingsfile m2repository );

use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::BuildPackages;
use UBOS::Macrobuild::BasicTasks::PullSources;
use UBOS::Macrobuild::BasicTasks::Stage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;

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
        'name'  => 'Build UBOS packages',
        'tasks' => [
            new UBOS::Macrobuild::BasicTasks::PullSources(
                    'name'           => 'Pull the sources that need to be built for db ' . $self->{db},
                    'usconfigs'      => $self->{usconfigs},
                    'sourcedir'      => '${builddir}/dbs/' . $db . '/ups'  ),
            new UBOS::Macrobuild::BasicTasks::BuildPackages(
                    'name'           => 'Building packages locally for db ' . $self->{db},
                    'sourcedir'      => '${builddir}/dbs/' . $db . '/ups',
                    'stopOnError'    => 0,
                    'm2settingsfile' => $self->{m2settingsfile},
                    'm2repository'   => $self->{m2repository} ),
            new UBOS::Macrobuild::BasicTasks::Stage(
                    'name'           => 'Stage new packages in local repository for db ' . $self->{db},
                    'stagedir'       => '${repodir}/${arch}/' . $db ),
            new UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase(
                    'name'         => 'Update package database with new packages',
                    'dbfile'       => '${repodir}/${arch}/' . $db . '/' . $db . '.db.tar.xz' )
        ]
    );

    return $self;
}

1;
