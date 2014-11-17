# 
# File and other utilities.
#

use strict;
use warnings;

package UBOS::Macrobuild::Utils;

use Cwd;

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

1;
