#
# Removes packages we built that are marked to be removed
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RemoveBuiltPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch builddir localSourcesDir db );

use Macrobuild::Task;

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

                my $m2BuildDir      = '${builddir}/maven';
                my $localSourcesDir = $run->getPropertyOrDefault( 'localSourcesDir', undef );

                my $dbs = $run->getProperty( 'db' );
                unless( ref( $dbs )) {
                    $dbs = [ $dbs ];
                }

                my $repoUsConfigs   = {};
                my @removeTaskNames = ();

                # create remove packages tasks
                foreach my $db ( @$dbs ) {
                    my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
                    $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

                    my $removeTaskName = "remove-$shortDb";
                    push @removeTaskNames, $removeTaskName;

                    $task->addParallelTask(
                            $removeTaskName,
                            UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages->new(
                                    'name'      => 'Remove built packages marked as such from ' . $db,
                                    'usconfigs' => $repoUsConfigs->{$db},
                                    'sourcedir' => '${builddir}/dbs/' . $db . '/ups',
                                    'db'        => $shortDb ));
                }

                $task->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name' => 'Merge update lists from dbs: ' . join( ' ', @$dbs ),
                        'keys' => \@removeTaskNames ));
            });
    return $self;
}

1;
