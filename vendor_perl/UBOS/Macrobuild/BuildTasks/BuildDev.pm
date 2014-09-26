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

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( @args );

    my @repos = (
        'os',
        'hl',
        'tools',
        'virt' );
    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $buildTasks = {};

    foreach my $repo ( @repos ) {
        $repoUpConfigs->{$repo} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $repo . '/up' );
        $repoUsConfigs->{$repo} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $repo . '/us' );

        $buildTasks->{"build-$repo"} = new UBOS::Macrobuild::ComplexTasks::BuildDevPackages(
                'name'       => 'Build dev packages in ' . $repo,
                'upconfigs'  => $repoUpConfigs->{$repo},
                'usconfigs'  => $repoUsConfigs->{$repo},
                'repository' => $repo );
    }
    my @buildTaskNames = keys %$buildTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'          => 'Build dev repos ' . join( ', ', @repos ) . ', then merge update lists and report',
        'splitTask'     => new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
            'repoUpConfigs' => $repoUpConfigs,
            'repoUsConfigs' => $repoUsConfigs ),
        'parallelTasks' => $buildTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge update lists from dev repositories: ' . join( ' ', @repos ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dev repositories: ' . join( ' ', @repos ),
                    'fields'      => [ 'updated-packages' ] )
            ]
        ));
    return $self;
}

1;
