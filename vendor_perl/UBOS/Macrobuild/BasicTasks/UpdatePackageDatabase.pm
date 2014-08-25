# 
# Build one or more packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;

use base qw( Macrobuild::Task );
use fields qw( dbfile );

use UBOS::Macrobuild::PacmanDbFile;
use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $staged = $in->{'staged-packages'};
    unless( exists( $in->{'staged-packages'} )) {
        error( "No staged-packages given in input" );
        return -1;
    }

    my @updated = ();
    if( %$staged ) {
        my $dbFile = new UBOS::Macrobuild::PacmanDbFile( $run->replaceVariables( $self->{dbfile} ));
        my @packageNames = values %$staged;

        if( $dbFile->addPackages( $run->getSettings()->getVariable( 'dbSignKey', undef ), \@packageNames ) == -1 ) {
            return -1;
        }
        @updated = values %$staged;
    }

    $run->taskEnded( $self, {
            'updated-packages' => \@updated
    } );

    if( @updated ) {
        return 0;
    } else {
        return 1;
    }
}

1;