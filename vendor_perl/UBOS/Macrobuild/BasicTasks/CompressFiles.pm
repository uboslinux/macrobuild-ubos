# 
# Compress files given by a glob
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CompressFiles;

use base qw( Macrobuild::Task );
use fields qw( files command );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $files   = $run->replaceVariables( $self->{files} );
    my $command = $run->replaceVariables( $self->{command} || 'xz' );

    my @files = glob $files;
    my $ret   = 0;
    if( @files ) {
        foreach my $file ( @files ) {
            if( UBOS::Utils::myexec( "$command '$file'" )) {
                error( 'Compressing failed:', $file );
                $ret = 1;
            }
        }
    } else {
        warning( 'No files to compress when expanding glob', $files );
    }
    
    if( $ret == 0 ) {
        $run->taskEnded(
                $self,
                { 'files' => \@files },
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

