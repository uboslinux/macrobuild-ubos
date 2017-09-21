#
# Remove one or more packages fetched from Arch and marked as such.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages;

use base qw( Macrobuild::Task );
use fields qw( arch upconfigs downloaddir );

use Macrobuild::Task;
use UBOS::Macrobuild::PackageUtils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $downloadDir = $self->getProperty( 'downloaddir' );
    my $arch        = $self->getProperty( 'arch' );

    my $upConfigs = $self->{upconfigs}->configs( $self );

    my $removedPackages = {};

    my $ok = 1;
    foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$repoName};

        my $removePackages = $upConfig->removePackages;
        unless( $removePackages ) {
            next;
        }

        foreach my $removePackage ( keys %$removePackages ) {
            my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $removePackage, $downloadDir, $arch );

            UBOS::Utils::deleteFile( @files );
            $removedPackages->{$repoName}->{$removePackage} = \@files;
        }
    }

    $run->setOutput( {
            'removed-packages' => $removedPackages
    } );

    if( !$ok ) {
        return FAIL;

    } elsif( keys %$removedPackages ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;
