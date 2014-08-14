# 
# Promotes all promotable packages in a particular repository in a particular
# channel to another.
#

use strict;
use warnings;

package IndieBox::Macrobuild::ComplexTasks::PromoteChannelRepository;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( upconfigs usconfigs repository );

use IndieBox::Macrobuild::BasicTasks::DeterminePromotablePackages;
use IndieBox::Macrobuild::BasicTasks::Stage;
use IndieBox::Macrobuild::BasicTasks::UpdatePackageDatabase;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Logging;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
            'tasks' => [
                new IndieBox::Macrobuild::BasicTasks::DeterminePromotablePackages(
                        'name'           => 'Determine which packages should be promoted',
                        'upconfigs'      => $self->{upconfigs},
                        'usconfigs'      => $self->{usconfigs},
                        'fromRepository' => '${repodir}/${fromChannel}/${arch}/' . $self->{repository},
                        'toRepository'   => '${repodir}/${toChannel}/${arch}/'   . $self->{repository} ),
                new IndieBox::Macrobuild::BasicTasks::Stage(
                        'name'        => 'Stage new packages in to-repository',
                        'stagedir'    => '${repodir}/${toChannel}/${arch}/' . $self->{repository} ),
                new IndieBox::Macrobuild::BasicTasks::UpdatePackageDatabase(
                        'name'         => 'Update package database with new packages',
                        'dbfile'       => '${repodir}/${toChannel}/${arch}/' . $self->{repository} . '/' . $self->{repository} . '.db.tar.xz' )
            ]
    );

    return $self;
}

1;
