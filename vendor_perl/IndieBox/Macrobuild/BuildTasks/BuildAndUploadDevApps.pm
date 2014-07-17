# 
# Build and publish a release of apps in dev
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildAndUploadDevApps;

use IndieBox::Macrobuild::BasicTasks::Upload;
use IndieBox::Macrobuild::ComplexTasks::BuildDevAppsPackages;
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

    my $usConfigs = IndieBox::Macrobuild::UsConfigs->allIn( '${configdir}/apps/us' );

    $self->{delegate} = new Macrobuild::CompositeTasks::Sequential(
        'tasks' => [
            new IndieBox::Macrobuild::ComplexTasks::BuildDevAppsPackages(
                'usconfigs'   => $usConfigs ),
            new IndieBox::Macrobuild::BasicTasks::Upload(
                'from'        => '${repodir}/${arch}/apps',
                'to'          => 'buildmaster@depot.indiebox.net:/var/lib/cldstr-archdepot/a00000000000000000000000000000003/${arch}/apps' ),
            new Macrobuild::CompositeTasks::SplitJoin(
                'parallelTasks' => {
                    'report-stdout' => new Macrobuild::BasicTasks::Report(
                        'name'        => 'Report build activity for apps',
                        'fields'      => [ 'updated-packages', 'repository-synced-to' ] ),
                    'report-mqtt' => new Macrobuild::BasicTasks::ReportViaMosquitto(
                        'fieldsChannels' => {
                            ''                     => '${mqttProducerId}/build/apps/run',
                            'updated-packages'     => '${mqttProducerId}/build/apps/updated-packages',
                            'repository-synced-to' => '${mqttProducerId}/build/apps/repository-synced-to'
                        }
                    )
                } )
        ]
    );
    return $self;
}

1;
