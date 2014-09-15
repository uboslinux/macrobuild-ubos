# 
# File utilities.
#

use strict;
use warnings;

package UBOS::Macrobuild::FileUtils;

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

    unless( $to =~ m!^/! ) {
        $to = getcwd . '/' . $to;
    }
    unless( $from =~ m!^/! ) {
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

1;
