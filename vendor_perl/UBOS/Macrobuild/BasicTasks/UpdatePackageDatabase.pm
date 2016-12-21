# 
# Update the package database given newly staged, or removed packages.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;

use base qw( Macrobuild::Task );
use fields qw( dbfile );

use UBOS::Logging;
use UBOS::Macrobuild::PacmanDbFile;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $stagedPackages   = $in->{'staged-packages'}   || {};
    my $unstagedPackages = $in->{'unstaged-packages'} || {};

    # While the structure looks the same, staged-packages always points to a single file per package,
    # while unstaged-packages points to an array: several versions of the same package may be unstaged
    # at the same time, while only one version of the same package is staged at the same time.

    my @addedPackageFiles   = ();
    my @removedPackageFiles = ();
    my $ret                 = 1;
    if( %$stagedPackages || %$unstagedPackages ) {
        my $dbFile = new UBOS::Macrobuild::PacmanDbFile( $run->replaceVariables( $self->{dbfile} ));
        my @stagedPackageFiles   = sort values %$stagedPackages;                # single file per package
        my @unstagedPackageFiles = sort map { @$_ } values %$unstagedPackages;  # multiple files per package

        my $dbSignKey = $run->getVariable( 'dbSignKey', undef );
        if( $dbSignKey ) {
            $dbSignKey = $run->replaceVariables( $dbSignKey );
        }
        if( @stagedPackageFiles ) {
            if( $dbFile->addPackages( $dbSignKey, \@stagedPackageFiles ) == -1 ) {
                $ret = -1;
            } else {
                @addedPackageFiles = @stagedPackageFiles;
            }
        }
        if( @unstagedPackageFiles ) {
            if( $dbFile->removePackages( $dbSignKey, \@unstagedPackageFiles ) == -1 ) {
                $ret = -1;
            } else {
                @removedPackageFiles = @unstagedPackageFiles;
            }
        }
        if( @addedPackageFiles || @removedPackageFiles ) {
            $ret = 0;
        }
    }

    if( $ret ) {
        $run->taskEnded(
                $self,
                {},
                $ret );
    } else {
        $run->taskEnded(
                $self,
                {
                    'added-package-files'   => \@addedPackageFiles,
                    'removed-package-files' => \@removedPackageFiles
                },
                $ret );
    }

    return $ret;
}

1;
