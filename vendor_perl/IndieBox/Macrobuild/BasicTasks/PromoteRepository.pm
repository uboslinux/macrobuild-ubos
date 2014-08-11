# 
# Promote one repository into another.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::PromoteRepository;

use base qw( Macrobuild::Task );
use fields qw( fromRepository toRepository );

use File::Spec;
use IndieBox::Utils;
use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $fromRepository = $run->replaceVariables( $self->{fromRepository} );
    my $toRepository   = $run->replaceVariables( $self->{toRepository} );

    unless( -d $toRepository ) {
        my $parent = File::Spec->rel2abs( $toRepository );
        if( $parent =~ m!^(.*)/[^/]+$! ) {
            $parent = $1;
            unless( -d $parent ) {
                IndieBox::Utils::mkdir( $parent );
            }
        }
        IndieBox::Utils::mkdir( $toRepository );
    }
    
    # rsync flags from: https://wiki.archlinux.org/index.php/Mirroring
    my $rsyncCmd = 
            'sudo'
            . ' rsync -rtlvH --delete-after --delay-updates --safe-links --max-delete=1000'
            . " $fromRepository/*"
            . " '$toRepository'";
    info( "Rsync command:", $rsyncCmd );
    my $ret = IndieBox::Utils::myexec( $rsyncCmd );

    my $toSuccess;
    unless( $ret ) {
        $toSuccess = $toRepository;
    } else {
        error( "rsync failed", $ret );
    }        

    $run->taskEnded( $self, {
            'promoted-from' => $fromRepository,
            'promoted-to'   => $toSuccess
    } );

    if( $toSuccess ) {
        return 0;
    } else {
        return -1;
    }
}

1;

