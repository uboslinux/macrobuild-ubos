# 
# Determine which packages, of the ones we want, have new versions
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;

use base qw( Macrobuild::Task );
use fields qw( dir upconfigs );

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
                if( $packageFileInPackageDatabase ) {
                    my @packageFileLocalCandidates   = map { s!.*/!!; } <$dir/$packageName-[0-9]*.$arch.pkg.*>;
                    
                    my $bestLocalCandidate = undef;
                    if( @packageFileLocalCandidates ) {
                        # we have one or more versions
                        @packageFileLocalCandidates = sortByPackageVersion( @packageFileLocalCandidates ); # most recent now at bottom
                        $bestLocalCandidate         = $packageFileLocalCandidates[-1];
                    } else {
                        # nothing local
                    }
                    if( !$bestLocalCandidate || $bestLocalCandidate != $packageFileInPackageDatabase ) {
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

##
# Sort package files by version
sub sortByPackageVersion {
    my @names = shift;

    my $out;
    IndieBox::Utils::myexec( "pacsort " . join( " ", @names ), undef, \$out );

    my @ret = split "\n", $out;
    return @ret;
}

1;

