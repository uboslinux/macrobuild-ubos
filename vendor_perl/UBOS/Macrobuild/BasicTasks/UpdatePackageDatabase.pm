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

    my @updatedPackageNames = ();
    my $ret                 = 1;
    if( %$stagedPackages || %$unstagedPackages ) {
        my $dbFile = new UBOS::Macrobuild::PacmanDbFile( $run->replaceVariables( $self->{dbfile} ));
        my @stagedPackageNames   = values %$stagedPackages;
        my @unstagedPackageNames = values %$unstagedPackages;
        my @allUnstagedPackageNames = map { @$_ } @unstagedPackageNames; # there can be multiple versions per package

        my $dbSignKey = $run->getVariable( 'dbSignKey', undef );
        if( $dbSignKey ) {
            $dbSignKey = $run->replaceVariables( $dbSignKey );
        }
        if( @stagedPackageNames ) {
            if( $dbFile->addPackages( $dbSignKey, \@stagedPackageNames ) == -1 ) {
                $ret = -1;
            } else {
                @updatedPackageNames = ( @updatedPackageNames, @stagedPackageNames );
            }
        }
        if( @unstagedPackageNames ) {
            if( $dbFile->removePackages( $dbSignKey, \@allUnstagedPackageNames ) == -1 ) {
                $ret = -1;
            } else {
                @updatedPackageNames = ( @updatedPackageNames, @allUnstagedPackageNames );
            }
        }
        if( @updatedPackageNames ) {
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
                { 'updated-packages' => \@updatedPackageNames },
                $ret );
    }

    return $ret;
}

1;
