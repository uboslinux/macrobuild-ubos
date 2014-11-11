# 
# Upload something to the depot
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Upload;

use base qw( Macrobuild::Task );
use fields qw( from to );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $from      = $run->replaceVariables( $self->{from} );
    my $to        = $run->replaceVariables( $self->{to} );

    my $ret = 1;
    if( -d $from ) {
        my @filesInFrom = <$from/*>;
        # we don't upload hidden files
        if( @filesInFrom ) {
            my $uploadKey = $run->getVariable( 'uploadSshKey' );

            # rsync flags from: https://wiki.archlinux.org/index.php/Mirroring
            my $rsyncCmd = 'rsync -rtlvH --delete-after --delay-updates --safe-links --max-delete=1000';
            if( $uploadKey ) {
                $rsyncCmd .= " -e 'ssh -i $uploadKey'";
            } else {
                $rsyncCmd .= ' -e ssh';
            }
            $rsyncCmd .= " $from/*"
                       . " '$to'";
            info( "Rsync command:", $rsyncCmd );
            if( UBOS::Utils::myexec( $rsyncCmd )) {
                error( "rsync failed" );
                $ret = -1;
            }
        }
    }

    if( $ret == 0 ) {
        $run->taskEnded(
                $self,
                { 'uploaded-to' => $to },
                $ret );
    } else {
        $run->taskEnded(
                $self,
                {},
                $ret );
    }

    return $ret;
}

1;

