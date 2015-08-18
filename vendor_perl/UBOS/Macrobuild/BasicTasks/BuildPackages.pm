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

            my $buildResult = $self->_buildPackage( $dir, $packageName, $inThisRepo, $packageSignKey );
            
            if( $buildResult == -1 ) {
                $ret = -1;
                if( $self->{stopOnError} ) {
                    last;
                }
            } elsif( $buildResult == 0 ) {
                if( $ret == 1 ) {
                    $ret = 0; # say we did something
                }
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
                debug( "Dir not updated: reponame '$repoName', subdir '$subdir', dir '$dir', packageName $packageName" );

                if( -e "$dir/$failedstamp" ) {
                    info( "Build of", $packageName, "failed last time, trying again: makepkg in", $dir );

                    my $buildResult = $self->_buildPackage( $dir, $packageName, $inThisRepo, $packageSignKey );
                    if( $buildResult == -1 ) {
                        $ret = -1;
                        if( $self->{stopOnError} ) {
                            last;
                        }
                    } elsif( $buildResult == 0 ) {
                        if( $ret == 1 ) {
                            $ret = 0; # say we did something
                        }
                    } # can also be 1
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
# Build a package if needed.
#
# ret: -1: error
#       0: ok
#       1: have package already, no need to build
sub _buildPackage {
    my $self           = shift;
    my $dir            = shift;
    my $packageName    = shift;
    my $builtRepo      = shift;
    my $packageSignKey = shift;

    UBOS::Utils::myexec( "touch $dir/$failedstamp" ); # in progress

    my $cmd  =  "cd $dir;";
    $cmd    .= ' env -i';
    $cmd    .=   ' PATH=/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl';
    $cmd    .=   ' LANG=C';
    $cmd    .=   ' GNUPGHOME=$GNUPGHOME';
    $cmd    .= ' makepkg -c -d -A'; # clean after, no dependency checks, no arch checks
    if( $packageSignKey ) {
        $cmd .= ' --sign --key ' . $packageSignKey;
    }

    info( 'Building package', $packageName );

    my $out;
    my $err;
    my $result = UBOS::Utils::myexec( $cmd, undef, \$out, \$err );
    my $both = $out . $err;
    # maven writes errors to stdout :-(

    if( $result ) {
        if( $both =~ /ERROR: A package has already been built/ ) {
            if( -e "$dir/$failedstamp" ) {
                UBOS::Utils::deleteFile( "$dir/$failedstamp" );
            }
            return 1;

        } else {
            error( "makepkg in $dir failed", $both );

            return -1;
        }

    } elsif( $both =~ m!Finished making:\s+(\S+)\s+(\S+)\s+\(! ) {
        $builtRepo->{$packageName} = "$dir/" . UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );

        if( -e "$dir/$failedstamp" ) {
            UBOS::Utils::deleteFile( "$dir/$failedstamp" );
        }
        return 0;

    } else {
        error( "could not find package built by makepkg in", $dir, $both );
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
