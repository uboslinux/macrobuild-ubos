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
        'hl' );
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
    my @mergeKeys      = ( '', @buildTaskNames );
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin( 
        'parallelTasks' => $buildTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new IndieBox::Macrobuild::BasicTasks::Upload(
                    'from'        => '${repodir}/${arch}',
                    'to'          => 'buildmaster@depot.indiebox.net:/var/lib/cldstr-archdepot/a00000000000000000000000000000003/${arch}' ),
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge update lists from dev repositories: ' . join( ' ', @repos ),
                    'keys'         => \@mergeKeys ),
                new Macrobuild::CompositeTasks::SplitJoin(
                    'parallelTasks' => {
                        'report-stdout' => new Macrobuild::BasicTasks::Report(
                            'name'        => 'Report build activity for dev repositories: ' . join( ' ', @repos ),
                            'fields'      => [ 'updated-packages', 'bootimages', 'vmdkimages', 'repository-synced-to' ] ),
                        'report-mqtt' => new Macrobuild::BasicTasks::ReportViaMosquitto(
                            'fieldsChannels' => {
                                ''                     => '${mqttProducerId}/build/run',
                                'updated-packages'     => '${mqttProducerId}/build/updated-packages',
                                'bootimages'           => '${mqttProducerId}/build/bootimages',
                                'vmdkimages'           => '${mqttProducerId}/build/vmdkimages',
                                'repository-synced-to' => '${mqttProducerId}/build/repository-synced-to'
                            }
                        )
                    }
                )
            ]
        )
    );
    return $self;
}

1;
