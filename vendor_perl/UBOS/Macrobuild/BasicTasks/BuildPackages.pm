# 
# Build one or more packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BuildPackages;

use base qw( Macrobuild::Task );
use fields qw( sourcedir );

use UBOS::Logging;

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
    
    my $packageSignKey = $run->getSettings()->getVariable( 'packageSignKey', undef );
    
    my $built      = {};
    my $notRebuilt = {};
    foreach my $repoName ( sort keys  %$dirsUpdated ) {
        my $repoInfo = $dirsUpdated->{$repoName};

        my $inThisRepo = {};
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName";
            if( $subdir && $subdir ne '.' ) {
                $dir .= "/$subdir";
            }

            my $packageName = _determinePackageName( $dir );
            debug( "dir updated: reponame '$repoName', subdir '$subdir', dir '$dir', packageName $packageName" );
            
            if( $self->_buildPackage( $dir, $packageName, $inThisRepo, $packageSignKey ) == -1 ) {
				return -1;
			}
        }
        if( %$inThisRepo ) {
            $built->{$repoName} = $inThisRepo;
        }
    }
    foreach my $repoName ( sort keys %$dirsNotUpdated ) {
        my $repoInfo = $dirsNotUpdated->{$repoName};

        my $inThisRepo = {};
        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName";
            if( $subdir ) {
                $dir .= "/$subdir";
            }

            my $packageName = _determinePackageName( $dir );
            debug( "dir not updated: reponame '$repoName', subdir '$subdir', dir '$dir', packageName $packageName" );

            if( -e "$dir/$failedstamp" ) {
				info( "build failed last time, trying again: makepkg in", $dir );

				if( $self->_buildPackage( $dir, $packageName, $inThisRepo, $packageSignKey ) == -1 ) {
					return -1;
				}
			} else {
				my $mostRecent = UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );
				if( $mostRecent ) {
                    $notRebuilt->{$repoName}->{$packageName} = "$dir/$mostRecent";
                } 
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
	my $self           = shift;
	my $dir            = shift;
	my $packageName    = shift;
	my $builtRepo      = shift;
	my $packageSignKey = shift;

	my $err;
	UBOS::Utils::myexec( "touch $dir/$failedstamp" ); # in progress
	my $cmd = "cd $dir; makepkg -c -f -d";
	if( $packageSignKey ) {
		$cmd .= ' --sign --key ' . $packageSignKey;
	}

    my $out;
	if( UBOS::Utils::myexec( $cmd, undef, \$out, \$err )) { # writes to stderr, don't complain about dependencies
		error( "makepkg in $dir failed", $err, " -- env was:\n", join( "\n", map { "$_ => " . $ENV{$_} } keys %ENV ));

		if( $self->{stopOnError} ) {
			return -1;
		}

	} elsif( $err =~ m!Finished making:\s+(\S+)\s+(\S+)\s+\(! ) {
		$builtRepo->{$packageName} = "$dir/" . UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );

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
