#
# Promotes all promotable packages in a particular repository in a particular
# channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel upconfigs usconfigs db repodir fromRepodir );

use Macrobuild::Task;
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

    $self->SUPER::new(
            %args,
            'setup' => sub {
                my $run  = shift;
                my $task = shift;

                $task->appendTask( UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages->new(
                        'name'        => 'Determine which packages should be promoted in ' . $self->{db},
                        'upconfigs'   => $self->{upconfigs},
                        'usconfigs'   => $self->{usconfigs},
                        'arch'        => '${arch}',
                        'channel'     => '${channel}',
                        'fromDb'      => '${fromRepodir}/${arch}/' . $self->{db},
                        'toDb'        => '${repodir}/${arch}/' . $self->{db} ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
                        'name'        => 'Stage new packages in ' . $self->{db},
                        'stagedir'    => $self->{repodir} . '/${arch}/' . $self->{db} ));

                $task->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
                        'name'        => 'Update package database with new packages in ' . $self->{db},
                        'dbfile'      => $self->{repodir} . '/${arch}/' . $self->{db} . '/' . $self->{db} . '.db.tar.xz',
                        'dbSignKey'   => '${dbSignKey}' ));

                return SUCCESS;
            } );

    return $self;
}

1;

