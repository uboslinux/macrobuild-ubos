# 
# Pull the sources of the packages we may have to build
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::PullSources;

use base qw( Macrobuild::Task );
use fields qw( usconfigs sourcedir );

use Macrobuild::Logging;
use Macrobuild::Utils;

my $failedstamp = ".build-in-progress-or-failed";
my %knownExtensions = (
	'.tar'    => 'tar xf',
	'.tar.gz' => 'tar xfz',
	'.tgz'    => 'tar xfz'
);

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $dirsUpdated    = {};
    my $dirsNotUpdated = {};

    my $usConfigs = $self->{usconfigs}->configs( $run->{settings} );
    foreach my $usConfig ( values %$usConfigs ) {
        Macrobuild::Logging::info( "Now processing upstream source config file", $usConfig->name );

        my $type = $usConfig->type;
        if( $type eq 'git' ) {
			$self->_pullFromGit( $usConfig, $dirsUpdated, $dirsNotUpdated, $run );

		} elsif( $type eq 'download' ) { 
			$self->_pullByDownload( $usConfig, $dirsUpdated, $dirsNotUpdated, $run );

		} else { 
			warn( "Skipping", $usConfig->name, "type", $type, "not known" );
		}
    }

    $run->taskEnded( $self, {
            'dirs-updated'     => $dirsUpdated,
            'dirs-not-updated' => $dirsNotUpdated
    } );
    if( %$dirsUpdated ) {
        return 0;
    } else {
        return 1;
    }
}

##
# Do this, for git
sub _pullFromGit {
	my $self           = shift;
	my $usConfig       = shift;
	my $dirsUpdated    = shift;
	my $dirsNotUpdated = shift;
	my $run            = shift;
	
	my $name     = $usConfig->name;
	my $url      = $usConfig->url;
	my $branch   = $usConfig->branch;
	my $packages = $usConfig->packages; # same name as directories

	my $sourceSourceDir = $run->replaceVariables( $self->{sourcedir} ) . "/$name";
	if( -d $sourceSourceDir ) {
		# Second or later update -- make sure the spec is still the same, if not, delete
		my $gitCmd = "git remote -v";
		my $out;
		my $err;
		IndieBox::Utils::myexec( "cd '$sourceSourceDir'; $gitCmd", undef, \$out );
		if( $out =~ m!^origin\s+\Q$url\E\s+\(fetch\)! ) {
			$out = undef;
			$gitCmd = "git checkout '$branch' ; git pull";
			IndieBox::Utils::myexec( "( cd '$sourceSourceDir'; $gitCmd )", undef, \$out, \$err );
            if( $err =~ m!^error!m ) {
                error( 'Error when attempting to pull git repository:', $url, 'into', $sourceSourceDir, "\n$err" );
            }

			# Determine which of the directories had changes in them
			my @updated;
			my @notUpdated;

            # This naive approach to parsing does not seem to work under all circumstances, e.g.
            # git might say:
            # foo/two => bar/three
            # so we rebuild everything even if only one directory has changed
            # foreach my $dir ( keys %$packages ) {
            #     if( $out =~ m!^\s\Q$dir\E/! ) {
            #         # git pull output seems to put a space at the beginning of any line that indicates a change
            #         # we look for anything below $dir, i.e. $dir plus appended slash
            #         push @updated, $dir;
            #
            #     } else {
            #         push @notUpdated, $dir;
            #     }
            # }
            if( $out =~ m!Already up-to-date! ) {
                push @notUpdated, keys %$packages;
            } else {
                push @updated, keys %$packages;
            }

			if( @updated ) {
				$dirsUpdated->{$name} = \@updated;
			}
			if( @notUpdated ) {
				$dirsNotUpdated->{$name} = \@notUpdated;
			}
		} else {
			info( "Source spec as changed. Starting over\n" );
			IndieBox::Utils::deleteRecursively( $sourceSourceDir );
		}
	}

	unless( -d $sourceSourceDir ) {
		# First-time checkout

		Macrobuild::Utils::ensureParentDirectoriesOf( $sourceSourceDir );
		
		my $gitCmd = "git clone";
		if( $branch ) {
			$gitCmd .= " --branch $branch"; 
		}
		$gitCmd .= " --depth 1"; 
		$gitCmd .= " '$url' '$name'";
		my $err;
		if( IndieBox::Utils::myexec( "cd '" . $run->replaceVariables( $self->{sourcedir} ) . "'; $gitCmd", undef, undef, \$err )) {
			error( "Failed to clone via", $gitCmd );
		} elsif( $packages ) {
			$dirsUpdated->{$name} = keys %$packages; # all of them
		} else {
			$dirsUpdated->{$name} = [ '' ];
		}
	}
}

##
# Do this, for a direct download
sub _pullByDownload {
	my $self           = shift;
	my $usConfig       = shift;
	my $dirsUpdated    = shift;
	my $dirsNotUpdated = shift;
	my $run            = shift;

	my $name      = $usConfig->name;
	my $url       = $usConfig->url;
    my $sourceDir = $run->replaceVariables( $self->{sourcedir} );

	my $ext;
    foreach my $e ( keys %knownExtensions ) {
        if( $url =~ m!\Q$e\E$! ) {
			$ext = $e;
			last;
		}
	}
	unless( $ext ) {
		warn( "Unknown extension in url", $url, "skipping" );
		return undef;
	}
	
    my $downloaded = "$sourceDir/$name$ext";
    if( -e $downloaded ) {
		my $downloadedNow = "$downloaded.now"; # don't destroy the previous file if download fails
		
		IndieBox::Utils::myexec( "curl '$url' -L -s -o '$downloadedNow' -z '$downloaded'" ); 
		if( -e $downloadedNow ) {
			# Build again from scratch
			IndieBox::Utils::deleteRecursively( "$sourceDir/$name", $downloaded );
			IndieBox::Utils::myExec( "mv '$downloadedNow' '$downloaded'" );
			
		} else {
		    $dirsNotUpdated->{$name} = [ "" ];
        }
	}
	unless( -e $downloaded ) {
		IndieBox::Utils::myexec( "curl '$url' -L -s -o '$downloaded'" );
		
		if( IndieBox::Utils::myexec( "cd $sourceDir; " . $knownExtensions{$ext} . " '$name$ext'" )) {
            error( $knownExtensions{$ext} . " failed" );
        }

		$dirsUpdated->{$name} = [ "" ];
	}
}

1;

