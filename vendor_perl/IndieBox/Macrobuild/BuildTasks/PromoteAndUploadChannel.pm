# 
# Promotes one channel to another and uploads
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::PromoteAndUploadChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use IndieBox::Macrobuild::BasicTasks::PromoteRepository;
use IndieBox::Macrobuild::BasicTasks::Upload;
use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
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

    my @repos = (
        'os',
        'hl',
        'tools',
        'virt' );

    my $promoteTasks = {};
    map { $promoteTasks->{"promote-$_"} = new IndieBox::Macrobuild::BasicTasks::PromoteRepository(
        'fromRepository' => '${fromChannel}/${arch}/' . $_,
        'toRepository'   => '${toChannel}/${arch}/'   . $_ ) } @repos;
    my @promoteTaskNames = keys %$promoteTasks;
    
    my $uploadTasks = {};
    map { $uploadTasks->{"upload-$_"} = new IndieBox::Macrobuild::BasicTasks::Upload(
        'from'        => '${fromChannel}/${arch}/' . $_,
        'to'          => '${uploadDest}/${arch}/'  . $_ ) } @repos;
    my @uploadTaskNames = keys %$uploadTasks;
            
    my @mergeKeys = ( '', @promoteTaskNames, @uploadTaskNames );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin(
                'parallelTasks' => $promoteTasks,
                'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
                    'tasks' => [
                        new Macrobuild::CompositeTasks::SplitJoin(
                            'parallelTasks' => $uploadTasks ),
                        new Macrobuild::CompositeTasks::MergeValuesTask(
                            'name'         => 'Merge promotion lists from repositories: ' . join( ' ', @repos ),
                            'keys'         => \@mergeKeys ),
                    ]
                )
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report promotion activity for repositories: ' . join( ' ', @repos ),
                'fields'      => [ 'promoted-to' ] )
        ]
    );

    return $self;
}

1;
