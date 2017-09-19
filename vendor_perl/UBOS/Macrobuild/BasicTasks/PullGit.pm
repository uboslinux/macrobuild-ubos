#
# Update a Git repository by pulling it
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PullGit;

use base qw( Macrobuild::Task );
use fields qw( dir branch );

use Macrobuild::Task;
use Macrobuild::Utils;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $dir    = $run->getProperty( 'dir' );
    my $branch = $run->getProperty( 'branch' );

    my $gitCmd = "git checkout -- . ; git checkout '$branch' ; git pull";

    my $out;
    my $err;
    UBOS::Utils::myexec( "( cd '$dir'; $gitCmd )", undef, \$out, \$err );
    if( $err =~ m!^error!m ) {
        error( 'Error when attempting to pull git repository:', $dir, "\n$err" );
        return FAIL;
    }

    $run->setOutput( {
            'updatedDir' => $dir
    } );

    return SUCCESS;
}

1;

