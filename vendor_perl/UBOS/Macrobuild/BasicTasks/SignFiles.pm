#
# Digitally sign files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SignFiles;

use base qw( Macrobuild::Task );
use fields qw( glob dir imageSignKey );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $imageSignKey = $self->getProperty( 'imageSignKey' );
    my $gpgHome      = $self->getValueOrDefault( 'GNUPGHOME', undef );

    my $errors = 0;
    my @signedFiles = ();
    if( $imageSignKey ) {
        my $dir      = $self->getProperty( 'dir' );
        my $glob     = $self->getProperty( 'glob' );
        my @allFiles = glob "$dir/$glob";
        my @toSign   = grep { -f $_ && ! -l $_ && ( ! -e "$_.sig" || -z "$_.sig" ) } @allFiles;

        if( @toSign ) {
            my $signCmd = '';
            if( $gpgHome ) {
                $signCmd .= "GNUPGHOME='$gpgHome' ";
            }
            $signCmd .= "gpg --detach-sign -u '$imageSignKey' --no-armor";

            foreach my $file ( @toSign ) {
                my $out;
                my $err;
                if( UBOS::Utils::myexec( "$signCmd '$file'", undef, \$out, \$err )) {
                    error( 'image signing failed:', $err );
                    ++$errors;
                } else {
                    push @signedFiles, $file;
                }
            }
        }
    }

    $run->setOutput( {
            'signed' => \@signedFiles
    } );

    if( $errors ) {
        return FAIL;
    } elsif( @signedFiles ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

