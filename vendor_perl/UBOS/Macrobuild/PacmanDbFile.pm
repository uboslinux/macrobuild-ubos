#!/usr/bin/perl
#
# A pacman DB file
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::PacmanDbFile;

use Archive::Tar;
use UBOS::Logging;
use UBOS::Utils;

use fields qw( filename containedPackages );

##
# $filename: filename of the pacman DB file
sub new {
    my $self     = shift;
    my $filename = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->{filename}          = $filename;
    $self->{containedPackages} = undef;

    return $self;
}

##
# Obtain the filename of the pacman DB file
# return: filename
sub fileName {
    my $self = shift;

    return $self->{filename};
}

##
# Obtain a hash of package names to package archive names, described in the DB file
# return: the hash
sub containedPackages {
    my $self = shift;

    unless( $self->{containedPackages} ) {
        my $realFile = $self->{filename};
        if( -l $realFile ) {
            if( $realFile =~ m!^(.*/)([^/]+)$! ) {
                $realFile = $1 . readlink( $realFile );
            } else {
                $realFile = readlink( $realFile );
            }
        }
        # Need to uncompress
        my $out;
        UBOS::Utils::myexec( "file '$realFile'", undef, \$out );
        my $tmpfile; # outside of the next block, otherwise will be deleted before we can use it
        if( $out =~ m!XZ compressed data! ) {
            $tmpfile = File::Temp->new();
            if( UBOS::Utils::myexec( "xz -d '$realFile' --stdout > " . $tmpfile->filename )) {
                error( 'xz command failed' );
            }
            $realFile = $tmpfile->filename;
        }
        my $tar = Archive::Tar->new( $realFile );
        if( $tar ) {
            my @files = $tar->get_files;

            my $ret   = {};
            foreach my $file ( @files ) {
                my $path = $file->full_path;
                if( $path =~ m!^(.*)-([^-]+)-([^-]+)/desc$! ) {
                    my $name    = $1;
                    my $content = $file->get_content;

                    if( $content =~ m!\%FILENAME\%\n(\S+)! ) {
                        my $packageArchive = $1;

                        $ret->{$name} = $packageArchive;
                    }
                }
            }
            $self->{containedPackages} = $ret;

        } else {
            error( 'Failed to read tar file, skipping', $realFile, '(was:', $self->{filename}, ')' );
        }
    }

    return $self->{containedPackages};
}

##
# Add one or more package files to this db. Note: this method uses
# package file names, not package names like removePackages does.
# $dbSignKey: if given, sign the package file after update
# $packageFiles: array of filenames containing the packages to be added
sub addPackages {
    my $self         = shift;
    my $dbSignKey    = shift;
    my $packageFiles = shift;

    my $cmd = 'repo-add';
    unless( UBOS::Logging::isTraceActive() ) {
        $cmd .= ' --quiet';
    }
    if( $dbSignKey ) {
        # Unlike makepkg's PACKAGER, repo-add does not currently support "Foo Bar <foo@bar.com>"
        # See bugs.archlinux.org/task/65240
        if( $dbSignKey =~ m!<(.*)>! ) {
            $dbSignKey = $1;
        }
        $cmd .= ' --sign --key "' . $dbSignKey . '"';
    }
    $cmd .= " '" . $self->{filename} . "'";
    $cmd .= ' ' . join( ' ', @$packageFiles );

    my $result;
    if( UBOS::Logging::isInfoActive() ) {
        $result = UBOS::Utils::myexec( $cmd );
    } else {
        my $out;
        $result = UBOS::Utils::myexec( $cmd, undef, \$out );
    }
    $self->{containedPackages} = undef;

    if( $result ) {
        error( 'Something went wrong when executing:', $cmd, " -- env was:\n" . join( "\n", map { "$_ => " . $ENV{$_} } keys %ENV ));
        return -1;
    }
    return 0;
}

##
# Remove one or more packages from this db. Note: this method uses
# package names, not package file names like addPackages does.
# $dbSignKey: if given, sign the package file after update
# $packageName: array of package names to be removed
sub removePackages {
    my $self         = shift;
    my $dbSignKey    = shift;
    my $packageNames = shift;

    my $cmd = 'repo-remove';
    unless( UBOS::Logging::isTraceActive() ) {
        $cmd .= ' --quiet';
    }
    if( $dbSignKey ) {
        # Unlike makepkg's PACKAGER, repo-remove does not currently support "Foo Bar <foo@bar.com>"
        # See bugs.archlinux.org/task/65240
        if( $dbSignKey =~ m!<(.*)>! ) {
            $dbSignKey = $1;
        }
        $cmd .= ' --sign --key ' . $dbSignKey;
    }
    $cmd .= " '" . $self->{filename} . "'";
    $cmd .= ' ' . join( ' ', @$packageNames );

    my $out;
    my $result = UBOS::Utils::myexec( $cmd, undef, \$out, \$out );
    $out = join( "\n", grep { ! /Package matching.*not found/ } split( "\n", $out ));
        # don't print "==> ERROR: Package matching 'foobar' not found."
    if( $result && $out ) {
        error( $out );
    }
    $self->{containedPackages} = undef;

    if( $result ) {
        error( 'Something went wrong when executing:', $cmd, " -- env was:\n" . join( "\n", map { "$_ => " . $ENV{$_} } keys %ENV ));
        return -1;
    }
    return 0;
}

##
# Create a copy of the file, with timestamp
# $ts: the timestamp
sub createTimestampedCopy {
    my $self = shift;
    my $ts   = shift;

    if( $self->{filename} =~ m!^(.*)/([^/]+)\.db$! ) {
        my $path     = $1;
        my $repoName = $2;

        my $fromDbFile = $self->{filename};
        my $toDbFile   = UBOS::Host::dbNameWithTimestamp( $repoName, $ts );

        foreach my $ext ( '.db', '.db.sig', '.db.tar.xz', '.db.tar.xz.sig', '.files', '.files.sig', '.files.tar.xz', '.files.tar.xz.sig' ) {
            if( -e "$fromDbFile$ext" ) {
                UBOS::Utils::copyRecursively( "$fromDbFile$ext", "$toDbFile$ext" );
            } else {
                error( 'Cannot find file:', "$fromDbFile$ext" );
            }
        }
    } else {
        error( 'Regex did not match:', $self->{filename} );
    }
}

##
# Create or update the history.json file that corresponds to this pacman db file.
# $ts: the timestamp
sub createUpdateHistoryFile {
    my $self = shift;
    my $ts   = shift;

    if( $self->{filename} =~ m!^(.*)/([^/]+)$! ) {
        my $historyFile = "$1/history.json";

        my $historyJson;
        if( -e $historyFile ) {
            $historyJson = UBOS::Utils::readJsonFromFile( $historyFile );
        }
        unless( $historyJson ) {
            $historyJson = { 'history' => [] };
        }
        push @{$historyJson->{history}}, { 'tstamp' => UBOS::Utils::time2rfc3339String( $ts ) };
        UBOS::Utils::writeJsonToFile( $historyJson, $historyFile );

    } else {
        error( 'Regex did not match:', $self->{filename} );
    }
}

1;

