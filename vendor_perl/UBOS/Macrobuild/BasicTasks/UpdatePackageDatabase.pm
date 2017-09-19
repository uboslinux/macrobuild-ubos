#
# Update the package database given newly staged, or removed packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;

use base qw( Macrobuild::Task );
use fields qw( dbfile dbSignKey );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PacmanDbFile;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $stagedPackages   = exists( $in->{'staged-packages'}   ) ? $in->{'staged-packages'}   : {};
    my $unstagedPackages = exists( $in->{'unstaged-packages'} ) ? $in->{'unstaged-packages'} : {};

    # While the structure looks the same, staged-packages always points to a single file per package,
    # while unstaged-packages points to an array: several versions of the same package may be unstaged
    # at the same time, while only one version of the same package is staged at the same time.

    my @addedPackageFiles   = ();
    my @removedPackageNames = ();
    my $ret                 = DONE_NOTHING;
    if( %$stagedPackages || %$unstagedPackages ) {
        my $dbFile = new UBOS::Macrobuild::PacmanDbFile( $run->getProperty( 'dbfile' ));
        my @stagedPackageFiles   = sort values %$stagedPackages;
        my @unstagedPackageNames = sort keys %$unstagedPackages;

        my $dbSignKey = $run->getPropertyOrDefault( 'dbSignKey', undef );
        if( $dbSignKey ) {
            $dbSignKey = $run->replaceVariables( $dbSignKey );
        }
        if( @stagedPackageFiles ) {
            if( $dbFile->addPackages( $dbSignKey, \@stagedPackageFiles ) == -1 ) {
                $ret = FAIL;
            } else {
                @addedPackageFiles = @stagedPackageFiles;
            }
        }
        if( @unstagedPackageNames ) {
            if( $dbFile->removePackages( $dbSignKey, \@unstagedPackageNames ) == -1 ) {
                $ret = FAIL;
            } else {
                @removedPackageNames = @unstagedPackageNames;
            }
        }
        if( @addedPackageFiles || @removedPackageNames ) {
            $ret = SUCCESS;
        }
    }

    if( $ret == SUCCESS ) {
        $run->setOutput( {
                'added-package-files' => \@addedPackageFiles,
                'removed-packages'    => \@removedPackageNames
        } );
    }

    return $ret;
}

1;
