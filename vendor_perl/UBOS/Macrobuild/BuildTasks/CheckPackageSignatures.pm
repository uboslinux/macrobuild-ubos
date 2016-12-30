# 
# Check that all packages in a channel have
# corresponding signature files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckPackageSignatures;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckSignatures;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    my $checkTasks = {};
    my @dbs        = UBOS::Macrobuild::Utils::determineDbs( 'dbs', %args );

    my @checkTasksSequence = map { "check-$_" } @dbs;

    # create check tasks tasks
    foreach my $db ( @dbs ) {
        $checkTasks->{"check-$db"} = new UBOS::Macrobuild::BasicTasks::CheckSignatures(
            'name'  => 'Check signatures for ' . $db,
            'dir'   => '${repodir}/${arch}/' . UBOS::Macrobuild::Utils::shortDb( $db ),
            'glob'  => '*.pkg.tar.xz' );
    }
    my @checkTaskNames = keys %$checkTasks;

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'                  => 'Check signatures from ${channel} dbs ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ) . ', then merge update lists and report',
        'parallelTasks'         => $checkTasks,
        'parallelTasksSequence' => \@checkTasksSequence,
        'joinTask'              => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge results from ${channel} dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'keys'         => \@checkTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report check activity from ${channel} for dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'fields'      => [ 'no-signature' ] )
            ]
        ));

    return $self;
}

1;
