# 
# Upload something to the depot
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Upload;

use base qw( Macrobuild::Task );
use fields qw( from to includeGlob excludeGlob );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $from        = $run->replaceVariables( $self->{from} );
    my $to          = $run->replaceVariables( $self->{to} );
    my $includeGlob = $self->{includeGlob};
    my $excludeGlob = $self->{excludeGlob};

    my $ret = 1;
    if( defined( $includeGlob ) && @$includeGlob && defined( $excludeGlob ) && @$excludeGlob ) {
        error( 'Must not specify both includeGlob and excludeGlob' );
        $ret = -1;
    }
    
    if( $ret == 1 && -d $from ) {
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
            if( defined( $includeGlob ) && @$includeGlob ) {
                # must include all directories
                $rsyncCmd .= " --include '*/'";
                $rsyncCmd .= join( '', map { " --include '$_'" } @$includeGlob );
                $rsyncCmd .= " --exclude '*'";
            }
            if( defined( $excludeGlob ) && @$excludeGlob ) {
                $rsyncCmd .= join( '', map { " --exclude '$_'" } @$excludeGlob );
                $rsyncCmd .= " --include '*/'";
            }

            $rsyncCmd .= " $from/"
                       . " '$to'";
            info( "Rsync command:", $rsyncCmd );
            if( UBOS::Utils::myexec( $rsyncCmd )) {
                error( "rsync failed" );
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

