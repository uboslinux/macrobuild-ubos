#
# Promotes one channel to another.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PromoteChannel;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db repodir fromRepodir );

use Macrobuild::Task;
use Macrobuild::CompositeTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
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

                my @promoteTasks = ();

                # create UpConfigs/UsConfigs, and also fetch tasks
                foreach my $db ( @$dbs ) {
                    my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
                    $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
                    $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us' );

                    my $promoteTaskName = "promote-$shortDb";

                    $task->addParallelTask(
                            $promoteTaskName,
                            UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository->new(
                                    'name'        => 'Promote channel repository ' . $shortDb,
                                    'arch'        => '${arch}',
                                    'channel'     => '${channel}',
                                    'upconfigs'   => $repoUpConfigs->{$shortDb},
                                    'usconfigs'   => $repoUsConfigs->{$shortDb},
                                    'db'          => $shortDb,
                                    'repodir'     => '${repodir}',
                                    'fromRepodir' => '${fromRepodir}' ));

                    push @promoteTasks, $promoteTaskName;
                }

                $task->setJoinTask( Macrobuild::CompositeTasks::MergeValues->new(
                        'name' => 'Merge promotion lists from repositories: ' . join( ' ', @$dbs ),
                        'keys' => \@promoteTasks ));

                return SUCCESS;
            } );

    return $self;
}

1;
