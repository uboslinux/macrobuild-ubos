# 
# Upload something to the depot
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Upload;

use base qw( Macrobuild::Task );
use fields qw( from to );

use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $from      = $run->replaceVariables( $self->{from} );
    my $to        = $run->replaceVariables( $self->{to} );
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
    my $ret = UBOS::Utils::myexec( $rsyncCmd );

    my $toSuccess;
    unless( $ret ) {
        $toSuccess = $to;
    } else {
        error( "rsync failed", $ret );
    }        

    $run->taskEnded( $self, {
            'uploaded-to' => $toSuccess
    } );

    if( $toSuccess ) {
        return 0;
    } else {
        return -1;
    }
}

1;

