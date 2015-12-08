# 
# Promotes all promotable packages in a particular repository in a particular
# channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( upconfigs usconfigs db );

use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages;
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
    
    $self->SUPER::new( %args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
            'tasks' => [
                new UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages(
                        'name'        => 'Determine which packages should be promoted in ' . $self->{db},
                        'upconfigs'   => $self->{upconfigs},
                        'usconfigs'   => $self->{usconfigs},
                        'fromDb'      => '${fromRepodir}/${arch}/' . $self->{db},
                        'toDb'        => '${repodir}/${arch}/' . $self->{db} ),
                new UBOS::Macrobuild::BasicTasks::Stage(
                        'name'        => 'Stage new packages in ' . $self->{db},
                        'stagedir'    => '${repodir}/${arch}/' . $self->{db} ),
                new UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase(
                        'name'         => 'Update package database with new packages in ' . $self->{db},
                        'dbfile'       => '${repodir}/${arch}/' . $self->{db} . '/' . $self->{db} . '.db.tar.xz' )
            ]
    );

    return $self;
}

1;
