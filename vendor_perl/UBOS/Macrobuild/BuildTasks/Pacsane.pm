# 
# Runs pacsane on a channel
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::Pacsane;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PacsaneRepository;
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

    my @dbs           = UBOS::Macrobuild::Utils::determineDbs( 'dbs',     %args );
    my @archDbs       = UBOS::Macrobuild::Utils::determineDbs( 'archDbs', %args );

    @dbs = ( @dbs, @archDbs );

    my $tasks = {};
    foreach my $db ( @dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );

        $tasks->{"pacsane-$db"} = new UBOS::Macrobuild::BasicTasks::PacsaneRepository(
                'dbfile' => '${repodir}/${arch}/' . $shortDb . '/' . $shortDb . '.db.tar.xz' );
    }
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $tasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge purge results from repositories: ' . join( ' ', @dbs ),
                    'keys'         => [ keys %$tasks ] ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report pacsane results for repositories: ' . join( ' ', @dbs ))
            ]
        ));

    return $self;
}

1;
