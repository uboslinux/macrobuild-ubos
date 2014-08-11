# 
# Promotes one channel to another.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::PromoteChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Logging;
use IndieBox::Macrobuild::BasicTasks::PromoteRepository;

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

    my $promoteTasks = {};
    map { $promoteTasks->{"promote-$_"} = new IndieBox::Macrobuild::BasicTasks::PromoteRepository(
        'fromRepository' => '${fromChannel}/' . $_,
        'toRepository'   => '${toChannel}/'   . $_ ) } @repos;
    my @promoteTaskNames = keys %$promoteTasks;
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'parallelTasks' => $promoteTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge promotion lists from repositories: ' . join( ' ', @repos ),
                    'keys'         => \@promoteTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report promotion activity for repositories: ' . join( ' ', @repos ),
                    'fields'      => [ 'updated-packages' ] )
            ]
        ));

    return $self;
}

1;
