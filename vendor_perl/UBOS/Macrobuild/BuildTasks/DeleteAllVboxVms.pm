# 
# Delete all VirtualBox Virtual Machines on this account. Sometimes they hang,
# and this is to clean up.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::DeleteAllVboxVms;

use base qw( Macrobuild::Task );
use fields qw( from to );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $ret = 1;
    my $out;

    if( UBOS::Utils::myexec( 'VBoxManage list vms', undef, \$out )) {
        error( 'VBoxManage list vms failed' );
        $ret = -1;
    } else {
        my %vms = ();
        foreach my $line ( split /\n/, $out ) {
            if( $line =~ m!^.*{(.*)}.*$! ) {
                my $vm = $1;
                
                UBOS::Utils::myexec( "VBoxManage controlvm '$vm' poweroff > /dev/null 2>&1" );
                # ignore if there are errors
                
                $vms{$vm} = $vm;
            }
        }
        
        sleep( 2 );
        
        foreach my $vm ( keys %vms ) {
            UBOS::Utils::myexec( "VBoxManage unregistervm '$vm' --delete > /dev/null 2>&1" );
            # ignore if there are errors
        }
        $ret = 0;
    }
    
    $run->taskEnded(
            $self,
            {},
            $ret );

    return $ret;
}

1;

