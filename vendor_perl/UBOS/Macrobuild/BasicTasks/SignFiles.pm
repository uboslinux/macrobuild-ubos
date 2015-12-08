# 
# Digitally sign files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SignFiles;

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

    my $imageSignKey = $run->getVariable( 'imageSignKey', undef ); # ok if not exists
    my $gpgHome      = $run->getVariable( 'GNUPGHOME',    undef ); # ok if not exists

    my $errors = 0;
    my @signedFiles = ();
    if( $imageSignKey ) {
        my @allFiles = glob "$inDir/$glob";
        my @toSign   = grep { -f $_ && ! -e "$_.sig" } @allFiles;

        if( @toSign ) {
            my $signCmd = '';
            if( $gpgHome ) {
                $signCmd .= "GNUPGHOME='$gpgHome' ";
            }
            $signCmd .= "gpg --detach-sign -u '$imageSignKey' --no-armor";

            foreach my $file ( @toSign ) {
                if( UBOS::Utils::myexec( "$signCmd '$file'", undef, \$out, \$err )) {
                    error( 'image signing failed:', $err );
                    ++$errors;
                } else {
                    push @signedFiles, @file;
                }
            }
        }
    }

    if( $errors ) {
        $run->taskEnded(
                $self,
                {
                    'signed' => \@signedFiles
                },
                -1 );

        return -1;

    } elsif( @signedFiles ) {
        $run->taskEnded(
                $self,
                {
                    'signed' => \@signedFiles
                },
                0 );

        return 0;
    } else {
        $run->taskEnded(
                $self,
                {
                    'signed' => \@signedFiles
                },
                1 );

        return 1;
    }
}

1;

