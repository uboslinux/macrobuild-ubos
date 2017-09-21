#
# Check that GPG has a private key for the given keyId
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CheckHavePrivateKey;

use base qw( Macrobuild::Task );
use fields qw( keyId );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overrides
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $keyId   = $self->getProperty( 'keyId' );
    my $gpgHome = $self->getValueOrDefault( 'GNUPGHOME', undef );

    my $cmd = '';
    if( $gpgHome ) {
        $cmd .= "GNUPGHOME='$gpgHome' ";
    }
    $cmd .= "gpg --list-secret-keys '$keyId' > /dev/null";

    if( UBOS::Utils::myexec( $cmd )) {
        return FAIL;
    }

    return SUCCESS;
}

1;

