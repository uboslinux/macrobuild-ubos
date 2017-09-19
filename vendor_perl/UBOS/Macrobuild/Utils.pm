#
# File and other utilities.
#

use strict;
use warnings;

package UBOS::Macrobuild::Utils;

use UBOS::Logging;

##
# Convenience method to determine whether an arch should be used, given
# the set of archs specified (or null)
# $arch: the arch
# $archs: if not given, use. If given, only use if $arch is in this array
# return: true or false
sub useForThisArch {
    my $arch  = shift;
    my $archs = shift;

    unless( defined( $archs )) {
        return 1;
    }
    foreach my $a ( @$archs ) {
        if( $a eq $arch ) {
            return 1;
        }
    }
    return 0;
}

##
# Helper method to determine the short name of the db
# $db: the db as returned by determineDbs()
# return: short db
sub shortDb {
    my $db = shift;

    my $ret = $db;
    $ret =~ s!.*/!!;
    return $ret;
}

##
# Given a hash, remove those item not for this arch. An item is for
# this arch, either if the value does not specify any archs, or the
# specified archs include our arch.
# $items: hash of items
# $arch: our arch
sub removeItemsNotForThisArch {
    my $items = shift;
    my $arch  = shift;

    foreach my $itemName ( keys %$items ) {
        my $itemData = $items->{$itemName};
        if( defined( $itemData ) && exists( $itemData->{archs} )) {
            unless( UBOS::Macrobuild::Utils::useForThisArch( $arch, $itemData->{archs} )) {
                delete $items->{$itemName};
                trace( 'Skipping item', $itemName, 'for arch', $arch );
            }
        }
    }
}

##
# Convenience method to ensure certain directories exist before or during a build.
# This creates missing parent directories recursively.
# @dirs: names of the directories
sub ensureDirectories {
    my @dirs = @_;

    foreach my $dir ( @dirs ) {
        _ensureDirectory( $dir );
    }
}

##
# Convenience method to ensure that about-to-created files have existing parent
# directories. This creates missing parent directories recursively.
# @files: names of the files whose parent directories may created.
sub ensureParentDirectoriesOf {
    my @files = @_;

    foreach my $file ( @files ) {
        if( $file =~ m!^(.+)/([^/]+)/?$! ) {
            _ensureDirectory( $1 );
        }
    }
}

sub _ensureDirectory {
    my $dir = shift;

    unless( -d $dir ) {
        ensureParentDirectoriesOf( $dir );

        mkdir( $dir ) || fatal( 'Could not create directory', $dir );
    }
}

1;
