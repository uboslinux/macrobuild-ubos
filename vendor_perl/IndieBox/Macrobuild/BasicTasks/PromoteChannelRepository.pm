# 
# Promote one repository in one channel into another.
#

use strict;
use warnings;

package IndieBox::Macrobuild::BasicTasks::PromoteChannelRepository;

use base qw( Macrobuild::Task );
use fields qw( upconfigs usconfigs fromRepository toRepository );

use File::Spec;
use IndieBox::Macrobuild::PackageUtils;
use IndieBox::Utils;
use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    $run->taskStarting( $self ); # input ignored

    my $fromChannel    = $run->getSettings->getVariable( 'fromChannel' );
    my $toChannel      = $run->getSettings->getVariable( 'toChannel' );
    my $fromRepository = $run->replaceVariables( $self->{fromRepository} );
    my $toRepository   = $run->replaceVariables( $self->{toRepository} );

    unless( -d $toRepository ) {
        my $parent = File::Spec->rel2abs( $toRepository );
        if( $parent =~ m!^(.*)/[^/]+$! ) {
            $parent = $1;
            unless( -d $parent ) {
                IndieBox::Utils::mkdir( $parent );
            }
        }
        IndieBox::Utils::mkdir( $toRepository );
    }

    my $upConfigs = $self->{upconfigs}->configs( $run->{settings} );
    my $arch      = $run->getVariable( 'arch' );
    
    my $toSuccess = {};

    while( my( $repoName, $upConfig ) = each %$upConfigs ) {
        while( my( $packageName, $packageInfo ) = each %{$upConfig->packages} ) {

            my @candidatePackages = IndieBox::Macrobuild::PackageUtils::packagesInDirectory( $packageName, $fromRepository, $arch );

            my $toPromote;
            if( exists( $packageInfo->{$toChannel}->{version} )) {
                if( exists( $packageInfo->{$toChannel}->{release} )) {
                    $toPromote = IndieBox::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$toChannel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $toChannel );
                }
            } else {
                $toPromote = IndieBox::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
            }
            if( defined( $toPromote )) {
                print "Promoting $toPromote\n";
            }
        }
    }

    $run->taskEnded( $self, {
            'promoted-from' => $fromRepository,
            'promoted-to'   => $toSuccess
    } );

    if( $toSuccess ) {
        return 0;
    } else {
        return -1;
    }
}

1;

