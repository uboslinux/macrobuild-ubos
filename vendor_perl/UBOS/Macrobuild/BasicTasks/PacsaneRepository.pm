# 
# Execute pacsane
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PacsaneRepository;

use base qw( Macrobuild::Task );
use fields qw( dbfile );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $dbfile = $run->replaceVariables( $self->{dbfile} );

    my $ret = 0;
    if( UBOS::Utils::myexec( "pacsane '$dbfile'" )) {
        $ret = -1;
    }

    $run->taskEnded(
            $self,
            {},
            $ret );

    return $ret;
}

1;

