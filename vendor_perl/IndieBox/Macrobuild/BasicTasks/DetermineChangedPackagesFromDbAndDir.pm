# 
# Determine which packages, of the ones we want, have new versions
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;

use base qw( Macrobuild::Task );
use fields qw( dir upconfigs );

use IndieBox::Macrobuild::PackageUtils;
use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $packageDatabases = $in->{'updated-package-databases'};
    my $dir              = $run->{settings}->replaceVariables( $self->{dir} );

    my $toDownload = {};
    if( %$packageDatabases ) {
        my $arch = $run->getVariable( 'arch' );

        my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );
        while( my( $repoName, $upConfig ) = each %$upConfigs ) {

            debug( 'Determining changed packages in repo', $repoName );
            
            my $packageDatabase = $packageDatabases->{$repoName};
            unless( $packageDatabase ) {
                # wasn't updated, nothing to do
                next;
            }
            my $repoDir            = "$dir/$repoName";
            my $packagesInDatabase = $packageDatabase->containedPackages(); # returns name => filename

            # in case you were wondering, here's the filtering that says which packages we want
            while( my( $packageName, $packageInfo ) = each %{$upConfig->packages} ) {
                my $packageFileInPackageDatabase = $packagesInDatabase->{$packageName};
                debug( 'Considering package', $packageName, ' in updated package database version', $packageFileInPackageDatabase );
                
                if( $packageFileInPackageDatabase ) {
                    my @packageFileLocalCandidates = IndieBox::Macrobuild::PackageUtils::packagesInDirectory( $packageName, $dir, $arch );
                    
                    my $bestLocalCandidate = undef;
                    if( @packageFileLocalCandidates ) {
                        # we have one or more versions
                        $bestLocalCandidate = IndieBox::BasicTasks::PackageUtils::mostRecentPackageVersion( @packageFileLocalCandidates ); # most recent now at bottom
                    } else {
                        # nothing local
                    }
                    if( !$bestLocalCandidate || $bestLocalCandidate ne $packageFileInPackageDatabase ) {
                        my $url = $upConfig->downloadUrlForPackage( $packageFileInPackageDatabase );
                        $toDownload->{$repoName}->{$packageName} = $url;
                    }
                } else {
                    warn( 'Failed to find package file for package', $packageName, 'in database for repo', $repoName );
                }
            }
        }
    }

    $run->taskEnded( $self, {
            'packages-to-download' => $toDownload
    } );
    if( %$toDownload ) {
        return 0;
    } else {
        return 1;
    }
}


1;

