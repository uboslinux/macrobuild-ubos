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

    my @dbs = (
            'os',
            'hl',
            'tools',
            'virt' );

    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $promoteTasks = {};
    my $uploadTasks = {};
    
    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $db . '/us' );

        $promoteTasks->{"promote-$repo"} = new UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository(
            'upconfigs' => $repoUpConfigs->{$db},
            'usconfigs' => $repoUsConfigs->{$db},
            'db'        => $db );

        $uploadTasks->{"upload-$repo"} = new UBOS::Macrobuild::BasicTasks::Upload(
            'from' => '${repodir}/${arch}/'    . $db,
            'to'   => '${uploadDest}/${arch}/' . $db );
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
                            'name'         => 'Merge promotion lists from repositories: ' . join( ' ', @dbs ),
                            'keys'         => \@mergeKeys ),
                    ]
                )
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report promotion activity for repositories: ' . join( ' ', @dbs ),
                'fields'      => [ 'promoted-to' ] )
        ]
    );

    return $self;
}

1;
