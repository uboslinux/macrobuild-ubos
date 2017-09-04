#
# File and other utilities.
#

use strict;
use warnings;

package UBOS::Macrobuild::Utils;

use Cwd;
use UBOS::Logging;
use UBOS::Utils;

##
# Express the second path as a relative path relative to the first. This is
# useful to create relative symlinks.
# $to: the absolute target of the symlink
# $from: the symlink
# return: the relative target of the symlink

sub relPath {
    my $to   = shift;
    my $from = shift;

    if( $to =~ m!^\./(.*)$! ) {
        $to = getcwd . '/' . $1;
    } elsif( $to !~ m!^/! ) {
        $to = getcwd . '/' . $to;
    }

    if( $from =~ m!^\./(.*)$! ) {
        $from = getcwd . '/' . $1;
    } elsif( $from !~ m!^/! ) {
        $from = getcwd . '/' . $from;
    }

    my @toPath   = split /\//, $to;
    my @fromPath = split /\//, $from;

    my $i = 0;
    # find common elements, and ignore them
    while( $i < @fromPath && $i < @toPath && $fromPath[$i] eq $toPath[$i] ) {
        ++$i;
    }

    my $toRelPath;
    if( $i > 0 ) {
        $toRelPath = '../' x ( @fromPath - $i - 1 ); # -1 because the last part is file itself
    } else {
        $toRelPath = '';
    }
    if( $i<@toPath ) {
        $toRelPath .= $toPath[$i];
        ++$i;

        while( $i<@toPath ) {
            $toRelPath .= '/' . $toPath[$i];
            ++$i;
        }
    }
    return $toRelPath;
}

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
# Helper method to extract the list of dbs from the %args
# $keyword: the keyword, such as 'db'
# %args: the arguments to a Task
# $return: array (may be empty) of dbs
sub determineDbs {
    my $keyword = shift;
    my %args    = @_;

    unless( exists( $args{'_settings'} )) {
        return ();
    }
    my $db = $args{'_settings'}->getVariable( $keyword );
    unless( defined( $db )) {
        return ();
    }
    if( 'ARRAY' eq ref( $db )) {
        return @$db;
    } elsif( ref( $db )) {
        fatal( '_settings member', $keyword, 'is not an ARRAY, is', ref( $db ));
    } else {
        return $db;
    }
}

##
# Helper method to convert the list of dbs into a string
# @dbs: the dbs
# return: the string
sub dbsToString {
    my @dbs = @_;

    if( @dbs ) {
        return join( ' ', @dbs );
    } else {
        return '<none>';
    }
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
# Determine the arch of this system
sub arch {

    my $ret;
    UBOS::Utils::myexec( 'uname -m', undef, \$ret );
    $ret =~ s!^\s+!!;
    $ret =~ s!\s+$!!;
    $ret =~ s!(armv[67])l!$1h!;

    return $ret;
}

##
# Determine the alternate arch of this system -- all the same, except that
# it prints 'pc' instead of 'x86_64'.
sub arch2 {

    my $ret = arch();
    if( $ret eq 'x86_64' ) {
        $ret = 'pc';
    }
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

1;
