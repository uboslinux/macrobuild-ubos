# 
# Build one or more packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BuildPackages;

use base qw( Macrobuild::Task );
use fields qw( sourcedir m2settingsfile m2repository );

use UBOS::Logging;
use UBOS::Utils;

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

    my $mvn_opts = ' -DskipTests';
    if( defined( $self->{m2settingsfile} )) {
        $mvn_opts .= ' --settings ' . $run->replaceVariables( $self->{m2settingsfile} );
    }
    # We need these for diet4j invocation in the build-scope Maven repository
    if( defined( $self->{m2repository} )) {
        $mvn_opts .= ' -Dmaven.repository=' . $run->replaceVariables( $self->{m2repository} );
    }
    
    my %allDirs = ( %$dirsUpdated, %$dirsNotUpdated );
    
    # determine package dependencies    
    my %dirToRepoName       = ();
    my %packageDependencies = ();
    my %packageToDir        = ();
    foreach my $repoName( keys %allDirs ) {
        my $repoInfo = $dirsUpdated->{$repoName} || $dirsNotUpdated->{$repoName};

        foreach my $subdir ( @$repoInfo ) {
            my $dir = $run->replaceVariables( $self->{sourcedir} ) . "/$repoName";
            if( $subdir && $subdir ne '.' ) {
                $dir .= "/$subdir";
            }
            $dirToRepoName{$dir} = $repoName;

            my $packageName = _determinePackageName( $dir );
            $packageToDir{$packageName} = $dir;

            my $dependencies = _readDependenciesFromPkgbuild( $dir );
            $packageDependencies{$packageName} = $dependencies;
        }
    }

    debug( sub { "Package dependencies:\n" . join( "\n", map { "    $_ => " . join( ', ', keys %{$packageDependencies{$_}} ) } keys %packageDependencies ) } );

    # determine in which sequence to build
    my @packageSequence = _determinePackageSequence( \%packageDependencies );
    my @dirSequence     = map { $packageToDir{$_} } @packageSequence;
    
    debug( sub { "Dir sequence is:\n" . join( "\n", map { "    $_" } @dirSequence ) } );

    # do the build, in @dirSequence
    my $ret        = 1;
    my $built      = {};
    my $notRebuilt = {};

    foreach my $dir ( @dirSequence ) {

        my $packageName = _determinePackageName( $dir );
        my $repoName    = $dirToRepoName{$dir};

        if( exists( $dirsUpdated->{$repoName} ) || -e "$dir/$failedstamp" ) {
            if( exists( $dirsUpdated->{$repoName} )) {
                debug( "Dir updated, rebuilding: reponame '$repoName', dir '$dir', packageName $packageName" );
            } else {
                debug( "Dir not updated, but failed last time, rebuilding: reponame '$repoName', dir '$dir', packageName $packageName" );
            }
            my $buildResult = $self->_buildPackage( $dir, $packageName, $built->{$repoName}, $packageSignKey, $mvn_opts );

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
            # dir not updated, and not failed last time
            my $mostRecent = UBOS::Macrobuild::PackageUtils::mostRecentPackageInDir( $dir, $packageName );
            if( $mostRecent ) {
                $notRebuilt->{$repoName}->{$packageName} = "$dir/$mostRecent";
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
    my $mvn_opts       = shift;

    UBOS::Utils::myexec( "touch $dir/$failedstamp" ); # in progress

    my $cmd  =  "cd $dir;";
    $cmd    .= ' env -i';
    $cmd    .=   ' PATH=/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl';
    $cmd    .=   ' LANG=C';
    $cmd    .=   ' GNUPGHOME=$GNUPGHOME';
    if( defined( $mvn_opts )) {
        my $trimmed = $mvn_opts;
        $trimmed =~ s/^\s+//;
        $trimmed =~ s/\s+$//;
        $cmd .= " 'MVN_OPTS=$trimmed'";
    }
    $cmd    .= ' makepkg -c -d -A'; # clean after, no dependency checks, no arch checks
    if( $packageSignKey ) {
        $cmd .= ' --sign --key ' . $packageSignKey;
    }

    info( 'Building package', $packageName );

    my $both;
    my $result = UBOS::Utils::myexec( $cmd, undef, \$both, \$both );
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

sub _readDependenciesFromPkgbuild {
    my $dir = shift;
    
    my $pkgBuild = "$dir/PKGBUILD";
    unless( -r $pkgBuild ) {
        error( 'Cannot read PKGBUILD in dir', $dir );
        return {};
    }
    my $out;
    if( UBOS::Utils::myexec( ". '$dir/PKGBUILD'" . ' && echo ${depends[@]}', undef, \$out )) {
        error( 'Executing PKGBUILD to find $depends failed in', $dir );
        return ();
    }
    my @packages = split /\s+/, $out;
    my %ret = ();
    @ret{@packages} = 0..$#packages;   # per http://stackoverflow.com/questions/2957879/perl-map-need-to-map-an-array-into-a-hash-as-arrayelement-array-index#2957903

    return \%ret;
}

##
# Topological sort, with thanks to https://en.wikipedia.org/wiki/Topological_sorting
#
sub _determinePackageSequence {
    my $deps = shift;
    my %done = ();    
    my @ret  = ();
    
    # we go through %$deps, and find nodes that don't have any more dependencies.
    # a node doesn't have dependencies if
    # 1) it has none, or
    # 2) the dependency is not in %$deps and thus out of scope, or
    # 3) the dependency is in %done already.
    
    while( 1 ) {
        if( scalar( keys %$deps ) <= scalar( @ret )) { # let's be safe
            last;
        }
        foreach my $current ( keys %$deps ) {
            if( exists( $done{$current} )) {
                next;
            }
            my $noDeps = 1;
            
            foreach my $currentDep ( keys %{$deps->{$current}} ) {
                unless( exists( $deps->{$currentDep} )) {
                    next;
                }
                if( exists( $done{$currentDep} )) {
                    next;
                }
                $noDeps = 0;
                last;
            }
            
            if( $noDeps ) {
                $done{$current} = $current;
                push @ret, $current;
            }
        }
    }
    return @ret;
}

1;
