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

    my @repos = (
        'os',
        'hl',
        'tools',
        'virt' );
    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    my $buildTasks  = {};
    my $uploadTasks = {};
    
    foreach my $repo ( @repos ) {
        $repoUpConfigs->{$repo} = UBOS::Macrobuild::UpConfigs->allIn( '${configdir}/' . $repo . '/up' );
        $repoUsConfigs->{$repo} = UBOS::Macrobuild::UsConfigs->allIn( '${configdir}/' . $repo . '/us' );

        $buildTasks->{"build-$repo"} = new UBOS::Macrobuild::ComplexTasks::BuildDevPackages(
                'name'       => 'Build dev packages in ' . $repo,
                'upconfigs'  => $repoUpConfigs->{$repo},
                'usconfigs'  => $repoUsConfigs->{$repo},
                'repository' => $repo );
        $uploadTasks->{"upload-$_"} = new UBOS::Macrobuild::BasicTasks::Upload(
                'from'        => '${repodir}/${arch}/'    . $repo,
                'to'          => '${uploadDest}/${arch}/' . $repo );
    }
    my @buildTaskNames  = keys %$buildTasks;
    my @uploadTaskNames = keys %$uploadTasks;
            
    my @mergeKeys = ( '', @buildTaskNames, @uploadTaskNames );
    
    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
        'name' => 'Build and upload dev repos ' . join( ', ', @repos ) . ', then report',
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin( 
                'name'          => 'Build dev repos ' . join( ', ', @repos ) . ', then merge update lists and upload',
                'splitTask'     => new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
                    'repoUpConfigs' => $repoUpConfigs,
                    'repoUsConfigs' => $repoUsConfigs ),
                'parallelTasks' => $buildTasks,
                'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
                    'tasks' => [
                        new Macrobuild::CompositeTasks::SplitJoin(
                            'parallelTasks' => $uploadTasks ),
                        new Macrobuild::CompositeTasks::MergeValuesTask(
                            'name'         => 'Merge update lists from dev repositories: ' . join( ' ', @repos ),
                            'keys'         => \@mergeKeys )
                    ]
                )
            ),
            new Macrobuild::BasicTasks::Report(
                'name'        => 'Report build activity for dev repositories: ' . join( ' ', @repos ),
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
