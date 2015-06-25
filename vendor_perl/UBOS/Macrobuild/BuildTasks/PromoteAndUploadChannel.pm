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
    my $promoteTasks = {};
    
    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $db . '/us' );

        $promoteTasks->{"promote-$repo"} = new UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository(
            'upconfigs' => $repoUpConfigs->{$db},
            'usconfigs' => $repoUsConfigs->{$db},
            'db'        => $db );
    }
    my @promoteTaskNames = keys %$promoteTasks;
            
    my @mergeKeys = ( '', @promoteTaskNames );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin(
                'parallelTasks' => $promoteTasks,
            ),
            new UBOS::Macrobuild::BasicTasks::Upload(
                'from'          => '${repodir}/${arch}',
                'to'            => '${uploadDest}/${arch}' ),
            new Macrobuild::BasicTasks::Report(
                'name'          => 'Report promotion activity',
                'fields'        => [ 'promoted-to' ] )
        ]
    );

    return $self;
}

1;
