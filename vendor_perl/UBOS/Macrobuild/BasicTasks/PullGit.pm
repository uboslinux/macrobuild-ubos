# 
# Update a Git repository by pulling it
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PullGit;

use base qw( Macrobuild::Task );
use fields qw( dbLocation branch );

use Macrobuild::Utils;
use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $dbLocation = $self->{dbLocation};
    my $branch     = $self->{branch};

    my $out;
    my $err;
    my $ret = 1;

    my $gitCmd = "git checkout -- . ; git checkout '$branch' ; git pull";

    UBOS::Utils::myexec( "( cd '$dbLocation'; $gitCmd )", undef, \$out, \$err );
    if( $err =~ m!^error!m ) {
        error( 'Error when attempting to pull git repository:', $dbLocation, "\n$err" );
        $ret = 0;
    }
        
    $run->taskEnded(
            $self,
            {
                'updatedDbLocation' => $dbLocation
            },
            $ret );

    return $ret;
}

1;

