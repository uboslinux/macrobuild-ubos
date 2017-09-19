#
# Updates the buildconfig directories by pulling from git
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PullBuildConfigs;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( db branch );

use Macrobuild::Task;
use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PullGit;

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

                # create git pull tasks
                my @pullTaskNames = ();
                foreach my $db ( @$dbs ) {
                    my $shortDb      = UBOS::Macrobuild::Utils::shortDb( $db );
                    my $pullTaskName = "pull-$shortDb";
                    push @pullTaskNames, $pullTaskName;

                    $task->addParallelTask(
                            $pullTaskName,
                            UBOS::Macrobuild::BasicTasks::PullGit->new(
                                    'name'   => 'Pull git ' . $db,
                                    'dir'    => $db,
                                    'branch' => '${branch}' ));
                }
                $task->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name'  => 'Merge update lists from dbLocations: ' . join( ' ', @$dbs ),
                        'keys'  => \@pullTaskNames ));

                return SUCCESS;
            } );

    return $self;
}

1;
