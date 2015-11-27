# 
# Upgrade the current system. Simply invokes 'ubos-admin update'.

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UpgradeSystem;

use base qw( Macrobuild::Task );
use fields qw( dbs );

use Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $ret = 0;

    if( UBOS::Utils::myexec( 'ubos-admin update' )) {
        $ret = -1;
    }

    $run->taskEnded( $self, {}, $ret );

    return $ret;
}

1;

