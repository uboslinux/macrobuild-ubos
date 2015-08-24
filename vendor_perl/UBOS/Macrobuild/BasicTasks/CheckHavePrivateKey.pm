# 
# Check that GPG has a private key for the given keyId
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;

use base qw( Macrobuild::Task );
use fields qw( keyId );

use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $keyId = $run->replaceVariables( $self->{keyId} );
    my $gpgHome = $run->getVariable( 'GNUPGHOME' );
    
    my $cmd = '';
    if( $gpgHome ) {
        $cmd .= "GNUPGHOME='$gpgHome' ";
    }
    $cmd .= "gpg --list-secret-keys '$keyId' > /dev/null";
    
    my $ret = 0;
    if( UBOS::Utils::myexec( $cmd )) {
        $ret = -1;
    }
    $run->taskEnded( $self, {}, $ret );

    return $ret;
}

1;

