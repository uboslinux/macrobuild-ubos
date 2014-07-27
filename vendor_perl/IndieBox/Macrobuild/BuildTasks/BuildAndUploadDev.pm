# 
# Build and publish in dev
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildAndUploadDev;

use IndieBox::Macrobuild::BasicTasks::Upload;
use IndieBox::Macrobuild::ComplexTasks::BuildDevPackages;
use Macrobuild::BasicTasks::Report;
use Macrobuild::BasicTasks::ReportViaMosquitto;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

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
    my $repoUpConfigs = {};
    my $repoUsConfigs = {};
    
    map { $repoUpConfigs->{$_} = IndieBox::Macrobuild::UpConfigs->allIn( '${configdir}/' . $_ . '/up' ) } @repos;
    map { $repoUsConfigs->{$_} = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/' . $_ . '/us' ) } @repos;

    my $buildTasks = {};
    map { $buildTasks->{"build-$_"} = new IndieBox::Macrobuild::ComplexTasks::BuildDevPackages(
                'upconfigs'   => $repoUpConfigs->{$_},
                'usconfigs'   => $repoUsConfigs->{$_},
                'repository'  => $_ ) } @repos;
    my @buildTaskNames = keys %$buildTasks;
    
    my $uploadTasks = {};
    map { $uploadTasks->{"upload-$_"} = new IndieBox::Macrobuild::BasicTasks::Upload(
                'from'        => '${repodir}/${arch}/'    . $_,
                'to'          => '${uploadDest}/${arch}/' . $_ ) } @repos;
    my @uploadTaskNames = keys %$uploadTasks;
            
    my @mergeKeys = ( '', @buildTaskNames, @uploadTaskNames );
    
    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential( 
        'tasks' => [
            new Macrobuild::CompositeTasks::SplitJoin( 
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
