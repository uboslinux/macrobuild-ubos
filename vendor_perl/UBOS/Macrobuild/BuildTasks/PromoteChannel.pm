# 
# Promotes one channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PromoteChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
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
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $promoteTasks  = {};
    my @dbs           = UBOS::Macrobuild::Utils::determineDbs( 'dbs', %args );

    my $localSourcesDir = $self->{_settings}->getVariable( 'localSourcesDir' );

    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        $promoteTasks->{"promote-$db"} = new UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository(
            'name'      => 'Promote channel repository ' . $db,
            'upconfigs' => $repoUpConfigs->{$db},
            'usconfigs' => $repoUsConfigs->{$db},
            'db'        => UBOS::Macrobuild::Utils::shortDb( $db ));
    }
    my @promoteTaskNames = keys %$promoteTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $promoteTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge promotion lists from repositories: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'keys'         => \@promoteTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report promotion activity for repositories: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'fields'      => [ 'added-package-files', 'removed-packages' ] )
        ));

    return $self;
}

1;
