# 
# Determine whether and which packages UBOS still needs if the provided
# Arch package was added to UBOS.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::Pacneed;

use base qw( Macrobuild::Task );
use fields qw( dbs );

use Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $ret = 1;

    my $localSourcesDir = $run->getVariable( 'localSourcesDir' );
    my $packages        = $run->getVariable( 'package', [] );
    my $dbs             = $run->getVariable( 'dbs',     [] );
    unless( ref( $packages ) eq 'ARRAY' ) {
        $packages = [ $packages ];
    }
    unless( ref( $dbs ) eq 'ARRAY' ) {
        $dbs = [ $dbs ];
    }
    unless( @$packages ) {
        error( 'No packages specified.' );
        $ret = 0;
    }

    # Determine which packages we have in UBOS
    my $havePackages = {}; # key: package name, value: db
    my $needPackages = {}; # key: package name, value: db

    if( $ret ) {
        info( 'Looking into dbs:', @$dbs );

        foreach my $db ( @$dbs ) {
            my $upConfigs = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' )->configs( $run->getSettings );
            my $usConfigs = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir )->configs( $run->getSettings );

            foreach my $configName ( sort keys %$upConfigs ) {
                my $upConfig = $upConfigs->{$configName};
                map { $havePackages->{$_} = $db } keys %{$upConfig->packages};
            }
            foreach my $configName ( sort keys %$usConfigs ) {
                my $usConfig = $usConfigs->{$configName};
                map { $havePackages->{$_} = $db } keys %{$usConfig->packages};
            }
        }

        foreach my $p ( @$packages ) {
            $ret &= _process( $p, $havePackages, $needPackages );
        }

        if( %$needPackages ) {
            # reverse map, so we can print by repo
            my $reverseNeedPackages = {};
            map {
                my $name = $_;
                my $repo = $needPackages->{$name};

                unless( exists( $reverseNeedPackages->{$repo} )) {
                    $reverseNeedPackages->{$repo} = [];
                }
                push @{$reverseNeedPackages->{$repo}}, $name;
                
            } sort keys %$needPackages;
            
            print "Need packages:\n";
            foreach my $repo ( sort keys %$reverseNeedPackages ) {
                print "$repo\n";
                print join( '', map { "    $_\n" } @{$reverseNeedPackages->{$repo}} );
            }
        } elsif( $ret ) {
            print "Have all needed packages.\n";
        }
    }

    $run->taskEnded( $self, {}, $ret ? 0 : -1 );

    return $ret ? 0 : -1;
}

##
# Process a single package
# $p: name of the package
# $havePackages: key: package name, value: db
# $needPackages: key: package name, value: db
# return: 0 if error, 1 if ok
sub _process {
    my $p            = shift;
    my $havePackages = shift;
    my $needPackages = shift;

    if( exists( $havePackages->{$p} )) {
        info( 'Processing package', $p, ': have already' );
        # we have this package
        return 1;
    }
    if( exists( $needPackages->{$p} )) {
        # we already decided we don't have this package, and don't need to process again
        return 1;
    }

    my $out;
    my $err;
    if( UBOS::Utils::myexec( "pacman -Si $p", undef, \$out, \$err )) {
        error( 'Cannot find package', $p );
        return 0;
    }

    # break by lines
    my $depsContent = undef;
    my $repo        = undef;
    foreach my $line ( split "\n", $out ) {
        if( $line =~ m!^Repository\s*:(.*)$! ) {
            $repo = $1;
            $repo =~ s!^\s+!!;
            $repo =~ s!\s+$!!;

        } elsif( $line =~ m!^Depends On\s*:(.*)$! ) {
            $depsContent = $1;
            $depsContent =~ s!^\s+!!;
            $depsContent =~ s!\s+$!!;
        }
    }
    if( $repo ) {
        info( 'Processing package', $p, ': need' );
        $needPackages->{$p} = $repo;
        my @deps = split /\s+/, $depsContent;
        my $ret = 1;

        foreach my $dep ( @deps ) {
            $dep =~ s!\s!!g;
            $dep =~ s!<?>?=.*$!!; # strip off version identifier if there is one
            unless( $dep eq 'None' ) {
                $ret &= _process( $dep, $havePackages, $needPackages );
            }
        }
        return $ret;
        
    } else {
        error( 'No Repository field found in pacman -Si', $p );
        return 0;
    }
}

1;

