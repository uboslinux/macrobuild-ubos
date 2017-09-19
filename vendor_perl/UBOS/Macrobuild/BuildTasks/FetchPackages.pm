#
# Fetches the Arch packages
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::FetchPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db builddir repodir dbSignKey );

use Macrobuild::Task;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
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

    $self->SUPER::new(
            %args,
            'setup' => sub {
                my $run  = shift;
                my $task = shift;

                my $dbs = $run->getProperty( 'db' );
                unless( ref( $dbs )) {
                    $dbs = [ $dbs ];
                }

                my $repoUpConfigs = {};
                my $repoUsConfigs = {};

                my @buildTasksSequence = ();

                # create UpConfigs/UsConfigs, and also fetch tasks
                foreach my $db ( @$dbs ) {
                    my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
                    $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
                    $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us' );

                    my $buildTaskName = "fetch-$shortDb";

                    $task->addParallelTask(
                            $buildTaskName,
                            UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages->new(
                                    'name'      => 'Fetch ' . $shortDb . ' packages',
                                    'arch'      => '${arch}',
                                    'channel'   => '${channel}',
                                    'builddir'  => '${builddir}',
                                    'repodir'   => '${repodir}',
                                    'upconfigs' => $repoUpConfigs->{$shortDb},
                                    'db'        => $shortDb,
                                    'dbSignKey' => '${dbSignKey}' ));

                    push @buildTasksSequence, $buildTaskName;
                }

                $task->setSplitTask( UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps->new(
                        'repoUpConfigs' => $repoUpConfigs,
                        'repoUsConfigs' => $repoUsConfigs ));

                $task->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name' => 'Merge update lists from dev dbs: ' . join( ' ', @$dbs ),
                        'keys' => \@buildTasksSequence ));

                return SUCCESS;
            } );

    return $self;
}

1;
