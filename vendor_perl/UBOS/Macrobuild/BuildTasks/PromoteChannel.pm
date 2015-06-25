# 
# Promotes one channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PromoteChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    my @dbs = UBOS::Macrobuild::Utils::dbs();

    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $promoteTasks  = {};

    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $db . '/us' );

        $promoteTasks->{"promote-$db"} = new UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository(
            'upconfigs' => $repoUpConfigs->{$db},
            'usconfigs' => $repoUsConfigs->{$db},
            'db'        => $db );
    }
    my @promoteTaskNames = keys %$promoteTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $promoteTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge promotion lists from repositories: ' . join( ' ', @dbs ),
                    'keys'         => \@promoteTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report promotion activity for repositories: ' . join( ' ', @dbs ),
                    'fields'      => [ 'updated-packages' ] )
            ]
        ));

    return $self;
}

1;
