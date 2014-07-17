# 
# Build one or more packages.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::BuildPackages;

use base qw( Macrobuild::Task );
use fields qw( sourcedir );

use Macrobuild::Logging;

my $failedstamp = ".build-in-progress-or-failed";

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    unless( exists( $in->{'dirs-to-build'} )) {
        error( "No dirs-to-build given in input" );
        return -1;
    }
    my $toBuild = $run->replaceVariables( $in->{'dirs-to-build'} );
    
    my $built = {};
    while( my( $repoName, $repoInfo ) = each %$toBuild ) {
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName/$subdir";

            info( "makepkg in $dir" );
            my $err;
            IndieBox::Utils::myexec( "touch $dir/$failedstamp" ); # in progress
            if( IndieBox::Utils::myexec( "cd $dir; makepkg -c -f", undef, undef, \$err )) { # writes to stderr
                error( "makepkg in $dir failed", $err );

                if( $self->{stopOnError} ) {
                    return -1;
                }

            } elsif( $err =~ m!Finished making:\s+(\S+)\s+(\S+)\s+\(! ) {
                my $packageName    = $1;
                my $packageVersion = $2;

                my $out;
                IndieBox::Utils::myexec( "echo $dir/$packageName-$packageVersion-*.pkg.tar.xz | pacsort | tail -1", undef, \$out );
                $out =~ s!^\s+!!;
                $out =~ s!\s+$!!;
                    
                $built->{$repoName}->{$packageName} = $out;

                if( -e "$dir/$failedstamp" ) {
                    IndieBox::Utils::deleteFile( "$dir/$failedstamp" );
                }

            } else {
                error( "could not find package built by makepkg in", $dir );
                return -1;
            }
        }
    }

    $run->taskEnded( $self, {
            'new-packages' => $built
    } );
    
    if( %$built ) {
        return 0;
    } else {
        return 1;
    }
}

1;
