# 
# Builds the repositories in dev, updates packages
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BuildDev;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::ComplexTasks::BuildDevPackages;
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
    my $buildTasks = {};

    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $db . '/us', '${localSourcesDir}' );

        $buildTasks->{"build-$db"} = new UBOS::Macrobuild::ComplexTasks::BuildDevPackages(
                'name'       => 'Build ' . $db . ' packages',
                'upconfigs'  => $repoUpConfigs->{$db},
                'usconfigs'  => $repoUsConfigs->{$db},
                'db'         => $db );
    }
    my @buildTaskNames = keys %$buildTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'          => 'Build dev dbs ' . join( ', ', @dbs ) . ', then merge update lists and report',
        'splitTask'     => new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
            'repoUpConfigs' => $repoUpConfigs,
            'repoUsConfigs' => $repoUsConfigs ),
        'parallelTasks' => $buildTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge update lists from dev dbs: ' . join( ' ', @dbs ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dev dbs: ' . join( ' ', @dbs ),
                    'fields'      => [ 'updated-packages' ] )
            ]
        ));
    return $self;
}

1;
