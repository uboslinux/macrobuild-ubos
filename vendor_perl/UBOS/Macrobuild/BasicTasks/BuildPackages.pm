# 
# Build one or more packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BuildPackages;

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
        my $inThisRepo = {};
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName";
            if( $subdir && $subdir ne '.' ) {
                $dir .= "/$subdir";
            }

            my $packageName = _determinePackageName( $dir );
            info( "dir updated: reponame '$repoName', subdir '$subdir', dir '$dir', packageName $packageName" );
            
            if( $self->_buildPackage( $dir, $packageName, $inThisRepo ) == -1 ) {
				return -1;
			}
        }
        if( %$inThisRepo ) {
            $built->{$repoName} = $inThisRepo;
        }
    }
    while( my( $repoName, $repoInfo ) = each %$dirsNotUpdated ) {
        my $inThisRepo = {};
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName";
            if( $subdir ) {
                $dir .= "/$subdir";
            }

            my $packageName = _determinePackageName( $dir );
            info( "dir not updated: reponame '$repoName', subdir '$subdir', dir '$dir', packageName $packageName" );

            if( -e "$dir/$failedstamp" ) {
				info( "build failed last time: makepkg in", $dir );

				if( $self->_buildPackage( $dir, $packageName, $inThisRepo ) == -1 ) {
					return -1;
				}
			} else {
				my $out;
				UBOS::Utils::myexec( "ls -1 $dir/$packageName-*.pkg.tar.xz | pacsort | tail -1", undef, \$out );
				$out =~ s!^\s+!!;
				$out =~ s!\s+$!!;
					
				$notRebuilt->{$repoName}->{$packageName} = $out;
			}
        }
        if( %$inThisRepo ) {
            $built->{$repoName} = $inThisRepo;
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
sub _buildPackage {
	my $self        = shift;
	my $dir         = shift;
	my $packageName = shift;
	my $builtRepo   = shift;

	my $err;
	UBOS::Utils::myexec( "touch $dir/$failedstamp" ); # in progress
	if( UBOS::Utils::myexec( "cd $dir; makepkg -c -f -d", undef, undef, \$err )) { # writes to stderr, don't complain about dependencies
		error( "makepkg in $dir failed", $err );

		if( $self->{stopOnError} ) {
			return -1;
		}

	} elsif( $err =~ m!Finished making:\s+(\S+)\s+(\S+)\s+\(! ) {
		my $out;
		UBOS::Utils::myexec( "ls -1 $dir/$packageName-*.pkg.tar.xz | pacsort | tail -1", undef, \$out );
		$out =~ s!^\s+!!;
		$out =~ s!\s+$!!;
			
		$builtRepo->{$packageName} = $out;

		if( -e "$dir/$failedstamp" ) {
			UBOS::Utils::deleteFile( "$dir/$failedstamp" );
		}

	} else {
		error( "could not find package built by makepkg in", $dir );
		return -1;
	}
	return 0;
}

sub _determinePackageName {
	my $dir = shift;

	my $packageName = $dir;
	$packageName =~ s!.*/!!;
	return $packageName;
}

1;
