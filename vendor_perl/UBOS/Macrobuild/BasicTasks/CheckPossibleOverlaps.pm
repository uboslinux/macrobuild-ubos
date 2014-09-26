# 
# Check that there are no overlaps in UpConfigs and UsConfigs
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;

use base qw( Macrobuild::Task );
use fields qw( repoUpConfigs repoUsConfigs );

use Macrobuild::Utils;
use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $ret = 0;

    # This is a degenerate task, it fatals out if something is wrong
    UBOS::Macrobuild::UpConfigs::checkNoOverlap( $self->{repoUpConfigs}, $run->getSettings() );
    UBOS::Macrobuild::UsConfigs::checkNoOverlap( $self->{repoUsConfigs}, $run->getSettings() );

    $run->taskEnded( $self, {} );

    return $ret;
}

1;

