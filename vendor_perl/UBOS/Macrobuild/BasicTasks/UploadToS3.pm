#!/usr/bin/perl
#
# Upload something to Amazon S3, which hosts the depot
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UploadToS3;

use base qw( Macrobuild::Task );
use fields qw( from to inexclude );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $from = $self->getProperty( 'from' );
    my $to   = $self->getProperty( 'to' );

    my $ret           = DONE_NOTHING;
    my $uploadedFiles = undef;
    my $deletedFiles  = undef;

    if( -d $from ) {
        my @filesInFrom = <$from/*>;
        # we don't upload hidden files
        if( @filesInFrom ) {
            UBOS::Utils::saveFile( "$from/LAST_UPLOADED", UBOS::Utils::time2string( time() ) . "\n" );

            my $cmd = 'aws s3 sync --dryrun --delete --acl public-read';

            my $inexclude = $self->getPropertyOrDefault( 'inexclude', undef );
            if( $inexclude ) {
                $cmd .= ' ' . $inexclude;
            }

            $cmd .= " '$from' '$to'";
            info( "Sync command:", $cmd );

            my $out;
            if( UBOS::Utils::myexec( $cmd, undef, \$out )) {
                error( "aws s3 sync failed:", $out );
                $ret = FAIL;
            } else {
                my @fileMessages = split "\n", $out;

                $uploadedFiles = [ map { my $s = $_; $s =~ s/^upload:\s+\S+\s+to\s+// ; $s } grep { /^upload: / } @fileMessages ];
                $deletedFiles  = [ map { my $s = $_; $s =~ s/^delete:\s+//            ; $s } grep { /^delete: / } @fileMessages ];
                $ret = SUCCESS;
            }
        }
    }

    if( $ret == SUCCESS ) {
        $run->setOutput( {
                'uploaded-to'    => $to,
                'uploaded-files' => $uploadedFiles,
                'deleted-files'  => $deletedFiles
        } );
    }

    return $ret;
}

1;

