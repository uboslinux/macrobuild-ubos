# 
# Check that files with a certain naming pattern in a directory
# have corresponding .sig files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CheckSignatures;

use base qw( Macrobuild::Task );
use fields qw( glob dir );

use UBOS::Logging;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;
use Macrobuild::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $errors = 0;

    my $dir           = $run->replaceVariables( $self->{dir} );
    my $glob          = $run->replaceVariables( $self->{glob} );
    my @allFiles      = glob "$dir/$glob";
    my @unsignedFiles = grep { -f $_ && ! -l $_ && ( ! -e "$_.sig" || -z "$_.sig" ) } @allFiles;

    debug( "Cecking files in $dir/$glob for corresponding signature files" );

    if( @unsignedFiles ) {
        $run->taskEnded(
                $self,
                {
                    'unsigned' => \@unsignedFiles
                },
                -1 );

        return -1;

    } else {
        $run->taskEnded(
                $self,
                {
                    'unsigned' => \@unsignedFiles
                },
                0 );

        return 0;
    }
}

1;

