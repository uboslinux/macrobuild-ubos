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
    my @unsignedFiles = grep { -f $_ && ! -l $_ && ( ! -e "$_.sig" ||   -z "$_.sig" ) } @allFiles;
    my @signedFiles   = grep { -f $_ && ! -l $_ && (   -e "$_.sig" && ! -z "$_.sig" ) } @allFiles;
    my @wrongSig      = ();
    my $ret = 0;

    trace( "Checking files in $dir/$glob for corresponding signature files" );

    foreach my $signedFile ( @signedFiles ) {
        my $out;
        if(    UBOS::Utils::myexec( "gpg --verify '$signedFile.sig' '$signedFile'", undef, \$out, \$out )
            && ( $out =~ m!buildmaster\@ubos.net! || $out !~ m!No public key! ))
        {
            # do not report packages not from US for which we don't have a public key
            push @wrongSig, $signedFile;
            $ret = -1;
        }
    }
    if( @unsignedFiles ) {
        $ret = -1;
    }

    $run->taskEnded(
            $self,
            {
                'unsigned'        => \@unsignedFiles,
                'wrong-signature' => \@wrongSig
            },
            $ret );

    return $ret;
}

1;

