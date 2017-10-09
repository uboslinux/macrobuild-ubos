#
# Purges outdated packages from a channel.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PurgePackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db maxAge repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PurgeChannelPackages;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::Utils;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $dbs = $self->getProperty( 'db' );
    if( !ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my @purgeTaskNames = ();
    foreach my $db ( @$dbs ) {
        my $shortDb  = UBOS::Macrobuild::Utils::shortDb( $db );
        my $taskName = "purge-$shortDb";
        push @purgeTaskNames, $taskName;

        $self->addParallelTask(
                $taskName,
                UBOS::Macrobuild::BasicTasks::PurgeChannelPackages->new(
                        'name'   => 'Purge channel packages on db ' . $db,
                        'dir'    => '${repodir}/${channel}/${arch}/' . $shortDb,
                        'maxAge' => '${maxAge}' ));
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge purge results from repositories: ' . join( ' ', @$dbs ),
            'keys' => \@purgeTaskNames ));

    return $self;
}

1;
