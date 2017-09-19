#
# Upload something to the depot
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Upload;

use base qw( Macrobuild::Task );
use fields qw( from to inexclude );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $from = $run->getProperty( 'from' );
    my $to   = $run->getProperty( 'to' );

    my $ret           = DONE_NOTHING;
    my $uploadedFiles = undef;
    my $deletedFiles  = undef;

    if( -d $from ) {
        my @filesInFrom = <$from/*>;
        # we don't upload hidden files
        if( @filesInFrom ) {
            UBOS::Utils::saveFile( "$from/LAST_UPLOADED", UBOS::Utils::time2string( time() ) . "\n" );

            my $uploadKey = $run->getOrUndef( 'uploadSshKey' );

            # rsync flags from: https://wiki.archlinux.org/index.php/Mirroring
            my $rsyncCmd = 'rsync -rtlvH --delete-after --delay-updates --links --safe-links --max-delete=1000';
            if( $uploadKey ) {
                $rsyncCmd .= " -e 'ssh -i $uploadKey'";
            } else {
                $rsyncCmd .= ' -e ssh';
            }
            my $inexclude = $run->getPropertyOrUndef( 'inexclude' );
            if( $inexclude ) {
                $rsyncCmd .= ' ' . $inexclude;
            }

            $rsyncCmd .= " $from/"
                       . " '$to'";
            info( "Rsync command:", $rsyncCmd );

            my $out;
            if( UBOS::Utils::myexec( $rsyncCmd, undef, \$out )) {
                error( "rsync failed:", $out );
                $ret = FAIL;
            } else {
                my @fileMessages = grep { ! /building file list/ }
                            grep { ! /sent.*received.*bytes/ }
                            grep { ! /total size is/ }
                            grep { ! /^\s*$/ }
                            split "\n", $out;
                $uploadedFiles = [ grep { ! /^deleting\s+\S+/ } grep { ! /\.\// } @fileMessages ];
                $deletedFiles  = [ map { my $s = $_; $s =~ s/^deleting\s+// ; $s } grep { /^deleting\s+\S+/ } @fileMessages ];
                $ret = SUCCESS;
            }
        }
    }

    if( $ret == SUCCESS ) {
        $run->setOutput( {
                'uploaded-to'    => $to,
                'uploaded-files' => $uploadedFiles,
                'deleted-files'  => $deletedFiles
        } );
    }

    return $ret;
}

1;

