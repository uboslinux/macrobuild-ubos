#
# Removes packages fetched from upstream marked to be removed
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RemoveFetchedPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch builddir repodir db dbSignKey );

use Macrobuild::Task;
use Macrobuild::BasicTasks::MergeValues;
use UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages;

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
                if( !ref( $dbs )) {
                    $dbs = [ $dbs ];
                }

                my $repoUpConfigs = {};

                my @removeTaskNames = ();
                foreach my $db ( @$dbs ) {
                    my $shortDb  = UBOS::Macrobuild::Utils::shortDb( $db );
                    my $taskName = "remove-fetched-packages-$shortDb";
                    push @removeTaskNames, $taskName;

                    $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );

                    $self->addParallelTask(
                            $taskName,
                            UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages->new(
                                    'name'      => 'Remove fetched packages marked as such from ' . $db,
                                    'arch'      => '${arch}',
                                    'builddir'  => '${builddir}',
                                    'repodir'   => '${repodir}',
                                    'upconfigs' => $repoUpConfigs->{$shortDb},
                                    'db'        => $shortDb,
                                    'dbSignKey' => '${dbSignKey}' ));
               }

                $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name' => 'Merge update lists from dbs: ' . join( ' ', @$dbs ),
                        'keys' => \@removeTaskNames ));

                return SUCCESS;
            } );

    return $self;
}

1;
