# 
# Build and publish in dev
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BuildAndUploadDev;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::BasicTasks::ReportViaMosquitto;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::BasicTasks::Upload;
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

    my @dbs = (
        'os',
        'hl',
        'tools',
        'virt' );
    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $buildTasks  = {};
    my $uploadTasks = {};
    
    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $db . '/up' );
        $repoUsConfigs->{$db} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $db . '/us' );

        $buildTasks->{"build-$db"} = new UBOS::Macrobuild::ComplexTasks::BuildDevPackages(
                'name'       => 'Build dev packages in ' . $db,
                'upconfigs'  => $repoUpConfigs->{$db},
                'usconfigs'  => $repoUsConfigs->{$db},
                'db'         => $db );
        $uploadTasks->{"upload-$db"} = new UBOS::Macrobuild::BasicTasks::Upload(
                'from'        => '${repodir}/${channel}/${arch}/' . $db,
                'to'          => '${uploadDest}/${arch}/'         . $db );
    }
    my @buildTaskNames  = keys %$buildTasks;
    my @uploadTaskNames = keys %$uploadTasks;
            
    my @mergeKeys = ( '', @buildTaskNames, @uploadTaskNames );
    
    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
        'name' => 'Build and upload dev dbs ' . join( ', ', @dbs ) . ', then report',
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin( 
                'name'          => 'Build dev dbs ' . join( ', ', @dbs ) . ', then merge update lists and upload',
                'splitTask'     => new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
                    'repoUpConfigs' => $repoUpConfigs,
                    'repoUsConfigs' => $repoUsConfigs ),
                'parallelTasks' => $buildTasks,
                'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
                    'tasks' => [
                        new Macrobuild::CompositeTasks::SplitJoin(
                            'parallelTasks' => $uploadTasks ),
                        new Macrobuild::CompositeTasks::MergeValuesTask(
                            'name'         => 'Merge update lists from dev dbs: ' . join( ' ', @dbs ),
                            'keys'         => \@mergeKeys )
                    ]
                )
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for dev dbs: ' . join( ' ', @dbs ),
                'fields'      => [ 'updated-packages', 'bootimages', 'vmdkimages', 'uploaded-to' ] ),
            new Macrobuild::BasicTasks::ReportViaMosquitto(
                'fieldsChannels' => {
                    ''                 => '${mqttProducerId}/build/run',
                    'updated-packages' => '${mqttProducerId}/build/updated-packages',
                    'bootimages'       => '${mqttProducerId}/build/bootimages',
                    'vmdkimages'       => '${mqttProducerId}/build/vmdkimages',
                    'uploaded-to'      => '${mqttProducerId}/build/repository-synced-to'
                }
            )
        ]
    );
    return $self;
}

1;
