#
# Promotes all promotable packages in a particular repository in a particular
# channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel upconfigs usconfigs db repodir fromChannel );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages;
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

    my $db        = $self->getProperty( 'db' );
    my $upconfigs = $self->getProperty( 'upconfigs' );
    my $usconfigs = $self->getProperty( 'usconfigs' );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages->new(
            'name'        => 'Determine which packages should be promoted in ' . $db,
            'upconfigs'   => $upconfigs,
            'usconfigs'   => $usconfigs,
            'arch'        => '${arch}',
            'channel'     => '${channel}',
            'fromDb'      => '${repodir}/${fromChannel}/${arch}/' . $db,
            'toDb'        => '${repodir}/${channel}/${arch}/' . $db ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
            'name'        => 'Stage new packages in ' . $db,
            'stagedir'    => '${repodir}/${channel}/${arch}/' . $db ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase->new(
            'name'        => 'Update package database with new packages in ' . $db,
            'dbfile'      => '${repodir}/${channel}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
            'dbSignKey'   => '${dbSignKey}' ));

    return $self;
}

1;

