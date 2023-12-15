#!/usr/bin/perl
#
# Trim the history: in history.json and the db files.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PurgeHistoryRatchet;

use base qw( Macrobuild::Task );
use fields qw( dir maxAge );

use Cwd qw( abs_path );
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $age    = $self->getProperty( 'maxAge' ); # seconds
    my $dir    = $self->getProperty( 'dir' );
    my $cutoff = time() - $age;

    my @keepList  = ();
    my @purgeList = ();
    my $ret       = DONE_NOTHING;

    my $dbName = $dir;
    $dbName =~ s!(.*)/!!; # last component of the path
    my $parentDir = $1;

    my $historyFile = "$dir/history.json";
    my $historyJson;

    if( -e $historyFile && ( $historyJson = UBOS::Utils::readJsonFromFile( $historyFile )) {
        # May not exist on some platforms

        my $historyArray    = $historyJson->{history};
        my $newHistoryArray = ();

        foreach my $historyElement ( @$historyArray ) {
            my $tstamp       = UBOS::Utils::lenientRfc3339string2time( $historyElement->{tstamp} );
            my $repoFileRoot = UBOS::Host::dbNameWithTimestamp( $dbName, $tstamp );
            my @files        =  map { "$parentDir/$repoFileRoot$_" } ( '.db', '.db.sig', '.db.tar.xz', '.db.tar.xz.sig', '.files.db', '.files.db.sig', '.files.db.tar.xz', '.files.db.tar.xz.sig' ) };

            if( $tstamp >= $cutoff ) {
                push @$newHistoryArray, $historyElement;
                push @keepList, @files;

            } else {
                push @purgeList, @files;
                UBOS::Utils::deleteFile(
                );
            }
        }
    } else {
        error( 'Failed to read:', $historyFile );
        $ret = $FAIL;
    }

    trace( 'Keeping', @keepList );
    trace( 'Purging', @purgeList );

    if( @purgeList ) {
        if( UBOS::Utils::deleteFile( @purgeList )) {
            $ret = SUCCESS;
        } else {
            error( 'Failed to purge some files:', @purgeList );
            $ret = FAIL;
        }
    }

    $run->setOutput( {
            'purged' => \@purgeList,
            'kept'   => \@keepList
    } );

    return $ret;
}

1;
