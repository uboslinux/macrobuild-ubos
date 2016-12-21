# 
# Fetches the Arch packages
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::FetchArchPackages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use Macrobuild::BasicTasks::Report;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::BasicTasks::SetupMaven;
use UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages;
use UBOS::Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    my $repoUpConfigs = {};
    my $buildTasks    = {};

    my @dbs                = UBOS::Macrobuild::Utils::determineDbs( 'dbs', %args );
    my @buildTasksSequence = map { "build-$_" } @dbs;

    # create fetch tasks
    foreach my $db ( @dbs ) {
        $repoUpConfigs->{$db} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );

        $buildTasks->{"build-$db"} = new UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages(
            'name'           => 'Fetch ' . $db . ' packages',
            'upconfigs'      => $repoUpConfigs->{$db},
            'db'             => UBOS::Macrobuild::Utils::shortDb( $db ))
    }
    
    # create check tasks
    my @checkTasks = (
        new UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps(
            'repoUpConfigs' => $repoUpConfigs ),
    );
    foreach my $keyType ( 'packageSignKey', 'dbSignKey', 'imageSignKey' ) {
        my $keyId = $self->{_settings}->getVariable( $keyType );
        if( $keyId ) {
            $keyId = $self->{_settings}->replaceVariables( $keyId );
        }
        if( $keyId ) {
            push @checkTasks, new UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey(
                    'name'  => 'Checking we have private key of type ' . $keyType . ' for ' . $keyId,
                    'keyId' => $keyId );
        }
    }

    my @buildTaskNames = keys %$buildTasks;

    $self->{delegate} = new Macrobuild::CompositeTasks::SplitJoin(
        'name'                  => 'Fetch dev dbs ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ) . ', then merge update lists and report',
        'splitTask'             => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => \@checkTasks ),
        'parallelTasks'         => $buildTasks,
        'parallelTasksSequence' => \@buildTasksSequence,
        'joinTask'              => new Macrobuild::CompositeTasks::Sequential(
            'tasks' => [
                new Macrobuild::CompositeTasks::MergeValues(
                    'name'         => 'Merge update lists from dev dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'keys'         => \@buildTaskNames ),
                new Macrobuild::BasicTasks::Report(
                    'name'        => 'Report build activity for dev dbs: ' . UBOS::Macrobuild::Utils::dbsToString( @dbs ),
                    'fields'      => [ 'added-package-files', 'removed-packages' ] )
            ]
        ));
    return $self;
}

1;
