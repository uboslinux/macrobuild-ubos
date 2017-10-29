#
# Check that files with a certain naming pattern in a directory
# have corresponding .sig files.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::CheckSignatures;

use base qw( Macrobuild::Task );
use fields qw( dir glob );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::Utils;

##
# @Override
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $errors = 0;

    my $dir           = $self->getProperty( 'dir' );
    my $glob          = $self->getProperty( 'glob' );

    my @allFiles      = glob "$dir/$glob";
    my @unsignedFiles = grep { -f $_ && ! -l $_ && ( ! -e "$_.sig" ||   -z "$_.sig" ) } @allFiles;
    my @signedFiles   = grep { -f $_ && ! -l $_ && (   -e "$_.sig" && ! -z "$_.sig" ) } @allFiles;
    my @wrongSig      = ();

    my $ret = SUCCESS;

    trace( "Checking files in $dir/$glob for corresponding signature files" );

    foreach my $signedFile ( @signedFiles ) {
        my $out;
        if(    UBOS::Utils::myexec( "gpg --verify '$signedFile.sig' '$signedFile'", undef, \$out, \$out )
            && ( $out =~ m!buildmaster\@ubos.net! || $out !~ m!No public key! ))
        {
            # do not report packages not from US for which we don't have a public key
            push @wrongSig, $signedFile;
            $ret = FAIL;

            error( 'Wrong signature on file:', $signedFile );
        }
    }
    if( @unsignedFiles ) {
        error( 'Unsigned files exist:', @unsignedFiles );

        $ret = FAIL;
    }

    $run->setOutput( {
            'unsigned'        => \@unsignedFiles,
            'wrong-signature' => \@wrongSig
    });

    return $ret;
}

1;

