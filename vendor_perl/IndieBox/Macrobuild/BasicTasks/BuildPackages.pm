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

    unless( exists( $in->{'dirs-updated'} )) {
        error( "No dirs-updated given in input" );
        return -1;
    }
    unless( exists( $in->{'dirs-not-updated'} )) {
        error( "No dirs-not-updated given in input" );
        return -1;
    }
    my $dirsUpdated    = $run->replaceVariables( $in->{'dirs-updated'} );
    my $dirsNotUpdated = $run->replaceVariables( $in->{'dirs-not-updated'} );
    
    my $built      = {};
    my $notRebuilt = {};
    while( my( $repoName, $repoInfo ) = each %$dirsUpdated ) {
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName/$subdir";

            info( "dir updated: makepkg in", $dir );
            
            if( $self->_buildPackage( $dir, $built->{$repoName} ) == -1 ) {
				return -1;
			}
        }
    }
    while( my( $repoName, $repoInfo ) = each %$dirsNotUpdated ) {
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName/$subdir";

            if( -e "$sourceSourceDir/$dir/$failedstamp" ) {
				info( "build failed last time: makepkg in", $dir );

				if( $self->_buildPackage( $dir, $built->{$repoName} ) == -1 ) {
					return -1;
				}
			} else {
				my $out;
				IndieBox::Utils::myexec( "cd $sourceSourceDir/$dir; ls $packageName-*.pkg.tar.xz | pacsort | tail -1", undef, \$out );
				$out =~ s!^\s+!!;
				$out =~ s!\s+$!!;
					
				$notRebuilt->{$repoName}->{$packageName} = $out;
			}
        }
	}

    $run->taskEnded( $self, {
            'new-packages' => $built,
            'old-packages' => $notRebuilt
    } );
    
    if( %$built ) {
        return 0;
    } else {
        return 1;
    }
}

##
_sub buildPackage {
	my $self      = shift;
	my $dir       = shift;
	my $builtRepo = shift;

	my $err;
	IndieBox::Utils::myexec( "touch $dir/$failedstamp" ); # in progress
	if( IndieBox::Utils::myexec( "cd $dir; makepkg -c -f -d", undef, undef, \$err )) { # writes to stderr, don't complain about dependencies
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
			
		$builtRepo->{$packageName} = $out;

		if( -e "$dir/$failedstamp" ) {
			IndieBox::Utils::deleteFile( "$dir/$failedstamp" );
		}

	} else {
		error( "could not find package built by makepkg in", $dir );
		return -1;
	}
	return 0;
}

1;
