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
    my $promoteTasks = {};
    my $uploadTasks = {};
    
    foreach my $repo ( @repos ) {
        $repoUpConfigs->{$repo} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $repo . '/up' );
        $repoUsConfigs->{$repo} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $repo . '/us' );

        $promoteTasks->{"promote-$repo"} = new UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository(
            'upconfigs'  => $repoUpConfigs->{$repo},
            'usconfigs'  => $repoUsConfigs->{$repo},
            'repository' => $repo );

        $uploadTasks->{"upload-$repo"} = new UBOS::Macrobuild::BasicTasks::Upload(
            'from' => '${repodir}/${toChannel}/${arch}/' . $repo,
            'to'   => '${uploadDest}/${arch}/'           . $repo );
    }
    my @promoteTaskNames = keys %$promoteTasks;
    my @uploadTaskNames  = keys %$uploadTasks;
            
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
