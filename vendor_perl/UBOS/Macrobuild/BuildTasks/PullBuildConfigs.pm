# 
# Updates the buildconfig directories by pulling from git
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PullBuildConfigs;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( dbLocation );

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::BasicTasks::SetupMaven;
use UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages;
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

    my $buildTasks         = {};
    my @buildTasksSequence = ();

    # create git pull tasks
    foreach my $dbLocation ( @{$self->{dbLocations}} ) {
        $buildTasks->{"build-$dbLocation"} = new UBOS::Macrobuild::BasicTasks::PullGit(
            'name'           => 'Pull git ' . $dbLocation,
            'dbLocation'     => $dbLocation
        );

        push @buildTasksSequence, "build-$dbLocation";
    }

    my @buildTaskNames = keys %$buildTasks;

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'                  => 'Pull git locations ' . join( ' ', @{$self->{dbLocations}} ),
        'parallelTasks'         => $buildTasks,
        'parallelTasksSequence' => \@buildTasksSequence,
        'joinTask'              => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge update lists from dbLocations: ' . . join( ' ', @{$self->{dbLocations}} ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dbLocations: ' . . join( ' ', @{$self->{dbLocations}} ),
                    'fields'      => [ 'updatedDbLocation' ] )
            ]
        ));
    return $self;
}

1;
