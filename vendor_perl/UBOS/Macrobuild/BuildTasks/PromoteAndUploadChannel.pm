# 
# Promotes one channel to another and uploads
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PromoteAndUploadChannel;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValuesTask;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::Upload;
use UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;


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
    
    map { $repoUpConfigs->{$_} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $_ . '/up' ) } @repos;
    map { $repoUsConfigs->{$_} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $_ . '/us' ) } @repos;

    my $promoteTasks = {};
    map { $promoteTasks->{"promote-$_"} = new UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository(
            'upconfigs'      => $repoUpConfigs->{$_},
            'usconfigs'      => $repoUsConfigs->{$_},
            'repository'     => $_ ) } @repos;
    my @promoteTaskNames = keys %$promoteTasks;
    
    my $uploadTasks = {};
    map { $uploadTasks->{"upload-$_"} = new UBOS::Macrobuild::BasicTasks::Upload(
        'from'        => '${repodir}/${toChannel}/${arch}/' . $_,
        'to'          => '${uploadDest}//${arch}/'          . $_ ) } @repos;
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
