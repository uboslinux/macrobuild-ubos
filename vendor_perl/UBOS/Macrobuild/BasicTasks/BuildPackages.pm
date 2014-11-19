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
    
    my $packageSignKey = $run->getVariable( 'packageSignKey', undef ); # ok if not exists

    my $ret        = 1;
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
                $ret = -1;
                if( $self->{stopOnError} ) {
                    last;
                }
            } elsif( $ret == 1 ) {
                $ret = 0; # we did something
            }
        }
        if( %$inThisRepo ) {
            $built->{$repoName} = $inThisRepo;
        }
    }
    if( $ret != -1 || !$self->{stopOnError} ) {
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
                        $ret = -1;
                        if( $self->{stopOnError} ) {
                            last;
                        } elsif( $ret == 1 ) {
                            $ret = 0; # we did something
                        }
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
    }

    $run->taskEnded(
            $self,
            {
                'new-packages' => $built,
                'old-packages' => $notRebuilt
            },
            $ret );

    return $ret;
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

    my $cmd  =  "cd $dir;";
    $cmd    .= ' env -i';
    $cmd    .=   ' PATH=/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl';
    $cmd    .=   ' LANG=C';
    $cmd    .=   ' GNUPGHOME=$GNUPGHOME';
    $cmd    .= ' makepkg -c -f -d -A'; # clean after, overwrite old build, no dependency checks, no arch checks
    if( $packageSignKey ) {
        $cmd .= ' --sign --key ' . $packageSignKey;
    }

    my $out;
    if( UBOS::Utils::myexec( $cmd, undef, \$out, \$err )) { # writes to stderr, don't complain about dependencies
        error( "makepkg in $dir failed", $err );

        return -1;

    } elsif( $err =~ m!Finished making:\s+(\S+)\s+(\S+)\s+\(! ) {
        $builtRepo->{$packageName} = "$dir/" . UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );

        if( -e "$dir/$failedstamp" ) {
            UBOS::Utils::deleteFile( "$dir/$failedstamp" );
        }
        return 0;

    } else {
        error( "could not find package built by makepkg in", $dir );
        return -1;
    }
}

sub _determinePackageName {
    my $dir = shift;

    my $packageName = $dir;
    $packageName =~ s!.*/!!;
    return $packageName;
}

1;
