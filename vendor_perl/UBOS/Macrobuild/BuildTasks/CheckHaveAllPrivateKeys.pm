#
# Check that we have all required private keys
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckHaveAllPrivateKeys;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( keyId );

use Macrobuild::Task;
use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;

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

                my $keyIds       = $run->getProperty( 'keyId' );
                my %uniqueKeyIds = (); # remove duplicates

                if( ref( $keyIds )) {
                    map { $uniqueKeyIds{$_} = $_; } @$keyIds;
                } else {
                    $uniqueKeyIds{$keyIds} = $keyIds;
                }

                my @checkTaskNames = ();

                foreach my $keyId ( keys %uniqueKeyIds ) {
                    my $checkTaskName = "check-$keyId";
                    push @checkTaskNames, $checkTaskName;

                    $task->addParallelTask(
                            $checkTaskName,
                            UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey->new(
                                    'name'  => 'Check that we have private key for ' . $keyId,
                                    'keyId' => $keyId ));
                }

                $task->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
                        'name' => 'Merge check results for keys: ' . join( ' ', @checkTaskNames ),
                        'keys' => \@checkTaskNames ));

                return SUCCESS;
            } );

    return $self;
}

1;
