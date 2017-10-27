#
# Unstage removed packages from the stage directory
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Unstage;

use base qw( Macrobuild::Task );
use fields qw( stagedir arch );

use Macrobuild::Task;
use UBOS::Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $unstaged     = {};
    my $removedFiles = [];

    if( exists( $in->{'removed-packages'} )) {

        my $removedPackages = $in->{'removed-packages'};

        my $stagedir = $self->getProperty( 'stagedir' );
        my $arch     = $self->getProperty( 'arch' );

        UBOS::Macrobuild::Utils::ensureDirectories( $stagedir );

        if( %$removedPackages ) {
            foreach my $uXConfigName ( sort keys %$removedPackages ) {
                my $uXConfigData = $removedPackages->{$uXConfigName};

                foreach my $packageName ( sort keys %$uXConfigData ) {

                    my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $stagedir, $arch );
                    @files    = map { "$stagedir/$_" } @files;
                    UBOS::Utils::deleteFile( @files );

                    push @$removedFiles, @files;
                }
            }
        }
    }

    $run->setOutput( {
            'unstaged-packages' => $unstaged,
            'removed-files'     => $removedFiles
    } );

    if( %$unstaged ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

