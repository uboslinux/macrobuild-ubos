# 
# Utility methods for packages. Some of the code is directly adapted from
# libalpm/version.c in pacman.
#

use strict;
use warnings;

package UBOS::Macrobuild::PackageUtils;

use UBOS::Utils;
use Macrobuild::Logging;

##
# Return all package files in all versions for package $packageName in the
# provided directory for a certain arch
# $packageName: the package name
# $dir: the directory
# $arch: the arch
# return: package file names, without path 
sub packageVersionsInDirectory {
    my $packageName = shift;
    my $dir         = shift;
    my $arch        = shift;
    
    my @files1 = <$dir/$packageName-[0-9]*-$arch.pkg.*>;
    my @files2 = <$dir/$packageName-[0-9]*-any.pkg.*>;
    my @ret = map { s!.*/!!; $_; } ( @files1, @files2 );

    return @ret;
}

##
# Sort package files of the same package by version
# @names: the file names of the package files
# return: @names, but sorted
sub sortByPackageVersion {
    my @names = @_;

    my @ret = sort comparePackageFileNamesByVersion @names;
    return @ret;
}

##
# Find the most recent version of a package file
# @names: the file names of the package files
# return: the member of @names that is most recent
sub mostRecentPackageVersion {
    my @names = @_;

    if( @names ) {
        my @sorted = sortByPackageVersion( @names ); # most recent now at bottom
        my $best   = $sorted[-1];

        return $best;

    } else {
        return undef;
    }
}

##
# Find the most recent version of a package file in a directory
# $dir: directory
# $packageName: name of the package
# return: most recent file name, not qualified with dir, or undef;
sub mostRecentPackageInDir {
	my $dir         = shift;
	my $packageName = shift;

    my $dh;
    unless( opendir( $dh, $dir )) {
		UBOS::Logging::warn( 'Cannot read directory', $dir );
		return undef;
	}
	my @packages = grep { /^$packageName-.*\.pkg\.tar\.xz$/ } readdir( $dh );
	closedir $dh;

    return mostRecentPackageVersion( @packages );
}

##
# Find the most recent version of a package file that is not later
# than the provided limit. This can be made more efficient.
# $limit: the latest version to be acceptable, in form of a hash that at least contains
#         'version' and 'release'
# @names: the file names of the package files
# return: the most recent version that is not later than the limit, or undef if not found
sub packageVersionNoLaterThan {
    my $limit = shift;
    my @names = @_;

    unless( @names ) {
        return undef;
    }
    my @sorted = sortByPackageVersion( @names );
    my $ret    = undef;
    foreach my $candidate ( @sorted ) {
        my %candidateParsed = parsePackageFileName( $candidate );
        if( $ret ) {
            if( compareParsedPackageFileNamesByVersion( $limit, \%candidateParsed ) < 0 ) {
                return $ret;
            } # else continue

        } else {
            # first time around
            if( compareParsedPackageFileNamesByVersion( $limit, \%candidateParsed ) < 0 ) {
                return undef; # all too new
            }
        }
            
        $ret = $candidate;
    }
    return $ret;
}


##
# Compare two package file names and determine which one is 'newer'.
# $a: one version
# $b: the other version
# return 1: a is newer than b
#        0: a and b are the same version
#       -1: b is newer than a
sub comparePackageFileNamesByVersion($$) {
    my $a = shift;
    my $b = shift;

    $a =~ s!.*/!!;
    $b =~ s!.*/!!;

    if( !$a ) {
        if( !$b ) {
            error( 'No package file names given' );
            return 0;
        } else {
            error( 'No first package file name given' );
            return -1;
        }
    } elsif( !$b ) {
        error( 'No second package file name given' );
        return 1;
    }
    
    if( $a eq $b ) {
        return 0;
	}

    my %aParsed = parsePackageFileName( $a );
    my %bParsed = parsePackageFileName( $b );

    my $ret = compareParsedPackageFileNamesByVersion( \%aParsed, \%bParsed );
    return $ret;
}

##
# Compare two parsed package file names and determine which one is 'newer'.
# %$a: one version
# %$b: the other version
sub compareParsedPackageFileNamesByVersion {
    my $aParsed = shift;
    my $bParsed = shift;

    if( defined( $aParsed->{name} ) && $aParsed->{name} && defined( $bParsed->{name} ) && $aParsed->{name} ne $bParsed->{name} ) {
        error( 'Should never compare different packages by version:', $aParsed->{name}, $bParsed->{name} );
        return 0;
    }
    if( defined( $aParsed->{arch} ) && $aParsed->{arch} && defined( $bParsed->{arch} ) && $aParsed->{arch} ne $bParsed->{arch} ) {
        error( 'Should never compare packages with different arch by version:', $aParsed->{arch}, $bParsed->{arch} );
        return 0;
    }

    my $ret = rpmvercmp( $aParsed->{epoch} || '0', $bParsed->{epoch} || '0' );
    unless( $ret ) {
        $ret = rpmvercmp( $aParsed->{version}, $bParsed->{version} );
        unless( $ret ) {
            $ret = rpmvercmp( $aParsed->{release}, $bParsed->{release} );
        }
    }

    return $ret;
}
        
##
# Split file name into package name, epoch, version, release,
# architecture, and compression components
# $s: package-[epoch:]version[-release]-arch.pkg.compression string
# return: ( name, epoch, version, release, arch, compression )
sub parsePackageFileName {
    my $s = shift;
    
    my $name;
    my $epoch;
    my $version;
    my $release;
    my $arch;
    my $compression;

    if( $s =~ m!^([-_.\w]+)-(?:([^:]+):)?([^-]+)(?:-(\d+))-(\w+)\.pkg\.([a-z.]+)$! ) {
        $name        = $1;
        $epoch       = $2;
        $version     = $3;
        $release     = $4;
        $arch        = $5;
        $compression = $6;
    } else {
        error( 'Cannot parse', $s, 'into epoch, version and release components' );
        return undef;
    }
    unless( $epoch ) {
        $epoch = '0';
    }
    return (
        'name'        => $name,
        'epoch'       => $epoch,
        'version'     => $version,
        'release'     => $release,
        'arch'        => $arch,
        'compression' => $compression );
}

##
# Compare alpha and numeric segments of two versions.
# $a: one version
# $b: the other version
# return 1: a is newer than b
#        0: a and b are the same version
#       -1: b is newer than a
sub rpmvercmp {
    my $a = shift;
    my $b = shift;

	my $ret = 0;

	# easy comparison to see if versions are identical
    if( $a eq $b ) {
        return 0;
    }

    my $aLen = length( $a );
    my $bLen = length( $b );

    my $one = 0; # Need indices instead of pointers in Perl vs C
    my $two = 0;
    my $i1;
    my $i2;
    
	# loop through each version segment of str1 and str2 and compare them
	while( $one < $aLen && $two < $bLen ) {
		while( $one < $aLen && substr( $a, $one, 1 ) !~ m!\w! ) {
            ++$one;
        }
		while( $two < $bLen && substr( $b, $two, 1 ) !~ m!\w! ) {
            ++$two;
        }

        # If we ran to the end of either, we are finished with the loop
		if( $one >= $aLen || $two >= $bLen ) {
            last;
        }

		# If the separator lengths were different, we are also finished
		if( $one != $two ) {
			return ( $one < $two ) ? -1 : 1;
		}

		$i1 = $one;
		$i2 = $two;

		# grab first completely alpha or completely numeric segment
		# leave one and two pointing to the start of the alpha or numeric
		# segment and walk $i1 and $i2 to end of segment
        my $isnum;
		if( substr( $a, $i1, 1 ) =~ m!\d! ) {
            while( $i1 < $aLen && substr( $a, $i1, 1 ) =~ m!\d! ) {
                ++$i1;
            }
            while( $i2 < $bLen && substr( $b, $i2, 1 ) =~ m!\d! ) {
                ++$i2;
            }
			$isnum = 1;

		} else {
            while( $i1 < $aLen && substr( $a, $i1, 1 ) =~ m![a-z]!i ) {
                ++$i1;
            }
            while( $i2 < $bLen && substr( $b, $i2, 1 ) =~ m![a-z]!i ) {
                ++$i2;
            }
			$isnum = 0;
		}

		# this cannot happen, as we previously tested to make sure that
		# the first string has a non-null segment
		if( $one == $i1) {
			$ret = -1;	# arbitrary
			return $ret;
		}

		# take care of the case where the two version segments are
		# different types: one numeric, the other alpha (i.e. empty)
		# numeric segments are always newer than alpha segments
		# XXX See patch #60884 (and details) from bugzilla #50977.
		if( $two == $i2 ) {
			$ret = $isnum ? 1 : -1;
			return $ret;
		}

		if( $isnum ) {
			# this used to be done by converting the digit segments
			# to ints using atoi() - it's changed because long
			# digit segments can overflow an int - this should fix that.

			# throw away any leading zeros - it's a number, right? */
			while( substr( $a, $one, 1 ) eq '0') {
                $one++;
            }
			while( substr( $b, $two, 1 ) eq '0') {
                $two++;
            }

			# whichever number has more digits wins
			if( $i1 - $one > $i2 - $two ) {
				$ret = 1;
                return $ret;
			}
			if( $i2 - $two > $i1 - $one ) {
				$ret = -1;
                return $ret;
			}
		}

		# strcmp will return which one is greater - even if the two
		# segments are alpha or if they are numeric.  don't return
		# if they are equal because there might be more segments to
		# compare
		my $rc = substr( $a, $one, $i1-$one ) cmp substr( $b, $two, $i2-$two );
		if( $rc ) {
			$ret = $rc < 1 ? -1 : 1;
            return $ret;
		}

        $one = $i1;
        $two = $i2;
	}

	# this catches the case where all numeric and alpha segments have */
	# compared identically but the segment separating characters were */
	# different */
	if( $one == $aLen && $two == $bLen ) {
		$ret = 0;
        return $ret;
	}

	# the final showdown. we never want a remaining alpha string to
    # beat an empty string. the logic is a bit weird, but:
    # - if one is empty and two is not an alpha, two is newer.
    # - if one is an alpha, two is newer.
    # - otherwise one is newer.
	if(    ( $one == $aLen && substr( $b, $two, 1 ) !~ m![a-z]!i )
        || substr( $a, $one, 1 ) =~ m![a-z]!i )
    {
		$ret = -1;
	} else {
		$ret = 1;
	}
	return $ret;
}

1;
