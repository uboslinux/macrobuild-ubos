# 
# Builds the repositories in dev, updates packages
#

use strict;
use warnings;

package IndieBox::Macrobuild::BuildTasks::BuildDev;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Logging;
use IndieBox::Macrobuild::ComplexTasks::BuildDevPackages;

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
    
    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin( 
        'parallelTasks' => $buildTasks,
        'joinTask'      => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValuesTask(
                    'name'         => 'Merge update lists from dev repositories: ' . join( ' ', @repos ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dev repositories: ' . join( ' ', @repos ),
                    'fields'      => [ 'updated-packages' ] )
            ]
        ));
    return $self;
}

1;
