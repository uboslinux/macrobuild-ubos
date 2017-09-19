#
# Check that all packages in a channel have
# corresponding signature files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckPackageSignatures;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch db repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckSignatures;

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

                my @checkTaskNames = ();
                foreach my $db ( @$dbs ) {
                    my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );

                    my $checkTaskName = "check-signatures-$shortDb";

                    $task->addParallelTask(
                            $checkTaskName,
                            UBOS::Macrobuild::BasicTasks::CheckSignatures->new(
                                    'name'  => 'Check signatures for ' . $db,
                                    'dir'   => '${repodir}/${arch}/' . $shortDb,
                                    'glob'  => '*.pkg.tar.xz' ));

                    push @checkTaskNames, $checkTaskName;
                }

                $task->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name' => 'Merge results from ${channel} dbs: ' . join( ' ', @$dbs ),
                        'keys' => \@checkTaskNames ));

                return SUCCESS;
            });

    return $self;
}

1;
