# 
# Upload something to the depot
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Upload;

use base qw( Macrobuild::Task );
use fields qw( from to inexclude );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $from = $run->replaceVariables( $self->{from} );
    my $to   = $run->replaceVariables( $self->{to} );

    my $ret = 1;
    
    if( $ret == 1 && -d $from ) {
        my @filesInFrom = <$from/*>;
        # we don't upload hidden files
        if( @filesInFrom ) {
            UBOS::Utils::saveFile( "$from/LAST_UPLOADED", UBOS::Utils::time2string( time() ) . "\n" );

            my $uploadKey = $run->getVariable( 'uploadSshKey' );

            # rsync flags from: https://wiki.archlinux.org/index.php/Mirroring
            my $rsyncCmd = 'rsync -rtlvH --delete-after --delay-updates --links --safe-links --max-delete=1000';
            if( $uploadKey ) {
                $rsyncCmd .= " -e 'ssh -i $uploadKey'";
            } else {
                $rsyncCmd .= ' -e ssh';
            }
            if( defined( $self->{inexclude} )) {
                $rsyncCmd .= ' ' . $run->replaceVariables( $self->{inexclude} );
            }

            $rsyncCmd .= " $from/"
                       . " '$to'";
            info( "Rsync command:", $rsyncCmd );

            my $out;
            if( UBOS::Utils::myexec( $rsyncCmd, undef, \$out )) {
                error( "rsync failed:", $out );
                $ret = -1;
            } else {
                $ret = 0;
            }
        }
    }
    if( $ret == 1 ) {
        debug( 'Skipped uploading', $from, $to, 'nothing to do' );
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

