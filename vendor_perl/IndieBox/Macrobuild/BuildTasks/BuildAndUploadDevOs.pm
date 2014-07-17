# 
# Build and publish a release of os in dev
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildAndUploadDevOs;

use IndieBox::Macrobuild::BasicTasks::Upload;
use IndieBox::Macrobuild::ComplexTasks::BuildDevOsPackages;
use Macrobuild::BasicTasks::Report;
use Macrobuild::BasicTasks::ReportViaMosquitto;
use Macrobuild::CompositeTasks::Sequential;

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

    my $upConfigs = IndieBox::Macrobuild::UpConfigs->allIn( '${configdir}/os/up' );
    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/os/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::ComplexTasks::BuildDevOsPackages(
                'upconfigs'   => $upConfigs,
                'usconfigs'   => $usConfigs ),
            new IndieBox::Macrobuild::BasicTasks::Upload(
                'from'        => '${repodir}/${arch}/os',
                'to'          => 'buildmaster@depot.indiebox.net:/var/lib/cldstr-archdepot/a00000000000000000000000000000003/${arch}/os' ),
            new Macrobuild::CompositeTasks::SplitJoin(
                'parallelTasks' => {
                    'report-stdout' => new Macrobuild::BasicTasks::Report(
                        'name'        => 'Report build activity for os',
                        'fields'      => [ 'updated-packages', 'bootimages', 'vmdkimages', 'repository-synced-to' ] ),
                    'report-mqtt' => new Macrobuild::BasicTasks::ReportViaMosquitto(
                        'fieldsChannels' => {
                            ''                     => '${mqttProducerId}/build/os/run',
                            'updated-packages'     => '${mqttProducerId}/build/os/updated-packages',
                            'bootimages'           => '${mqttProducerId}/build/os/bootimages',
                            'vmdkimages'           => '${mqttProducerId}/build/os/vmdkimages',
                            'repository-synced-to' => '${mqttProducerId}/build/os/repository-synced-to'
                        }
                    )
                } )
                        
        ]
    );
    return $self;
}

1;
