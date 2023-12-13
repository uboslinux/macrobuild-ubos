#!/usr/bin/perl
#
# Upload something to the depot
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Upload;

use base qw( Macrobuild::Task );
use fields qw( from to inexclude genindextitle awsprofile awsendpoint releasetimestamp );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $from             = $self->getProperty( 'from' );
    my $to               = $self->getProperty( 'to' );
    my $genindextitle    = $self->getProperty( 'genindextitle' );
    my $awsProfile       = $self->getProperty( 'awsprofile' );
    my $awsEndpoint      = $self->getProperty( 'awsendpoint' );
    my $releaseTimeStamp = $self->getProperty( 'releasetimestamp' );

    my $ret           = DONE_NOTHING;
    my $uploadedFiles = undef;
    my $deletedFiles  = undef;

    if( $releaseTimeStamp ) {
        $releaseTimeStamp = UBOS::Utils::lenientRfc3339string2time( $releaseTimeStamp );
    }

    if( -d $from ) {
        my @filesInFrom = <$from/*>;
        # we don't upload hidden files
        if( @filesInFrom ) {
            if( -e "$from/LAST_UPLOADED" ) {
                # We don't need this any more
                UBOS::Utils::deleteFile( "$from/LAST_UPLOADED" );
            }

            if( $genindextitle ) {
                UBOS::Utils::saveFile( "$from/index.html", generateIndex( $from, $genindextitle ));
            }

            my $baseCmd;
            my $uploadToS3     = 0;
            my $uploadViaRsync = 0;

            if( $to =~ m!^s3://! ) {
                # S3 upload
                if( $awsProfile ) {
                    $baseCmd = 'aws --profile=' . $awsProfile;
                }
                if( $awsEndpoint ) {
                    $baseCmd .= ' --endpoint' . $awsEndpoint;
                }
                $baseCmd .= ' s3 sync --delete --acl public-read';
                $uploadToS3 = 1;

            } else {
                # rsync over ssh upload
                 my $uploadKey = $self->getValueOrDefault( 'uploadSshKey', undef );

                # rsync flags from: https://wiki.archlinux.org/index.php/Mirroring
                $baseCmd = 'rsync -rtlvH --delete-after --delay-updates --links --safe-links --max-delete=1000';
                if( $uploadKey ) {
                    $baseCmd .= " -e 'ssh -i $uploadKey'";
                } else {
                    $baseCmd .= ' -e ssh';
                }
                $uploadViaRsync = 1;
            }

            # Stage 1: upload the data files

            my $cmd1 = $baseCmd;
            my $inexclude = $self->getPropertyOrDefault( 'inexclude', undef );
            if( $inexclude ) {
                $cmd1 .= ' ' . $inexclude;
            }

            $cmd1 .= " '$from/' '$to'";
            info( "Upload command:", $cmd1 );

            my $out;
            if( UBOS::Utils::myexec( $cmd1, undef, \$out )) {
                error( "$cmd1 failed:", $out );
                $ret = FAIL;
            } else {
                if( $uploadToS3 ) {
                    my @fileMessages = split( /[\n\r]+/, $out );

                    # These dudes emit "progress message\ractual message\n", where
                    # the progress message does not actually show in a terminal.
                    # We treat those as two lines.

                    $uploadedFiles = [ map { my $s = $_; $s =~ s/^upload:\s+\S+\s+to\s+// ; $s } grep { /^upload: / } @fileMessages ];
                    $deletedFiles  = [ map { my $s = $_; $s =~ s/^delete:\s+//            ; $s } grep { /^delete: / } @fileMessages ];
                }
                if( $uploadViaRsync ) {
                    my @fileMessages = grep { ! /building file list/ }
                                grep { ! /sent.*received.*bytes/ }
                                grep { ! /total size is/ }
                                grep { ! /^\s*$/ }
                                split "\n", $out;
                    $uploadedFiles = [ grep { ! /^deleting\s+\S+/ } grep { ! /\.\// } @fileMessages ];
                    $deletedFiles  = [ map { my $s = $_; $s =~ s/^deleting\s+// ; $s =~ s/\s//g; $s } grep { /^deleting\s+\S+/ } @fileMessages ];
                }
                $ret = SUCCESS;
            }

            # Stage 2: upload the history.json file

            my $historyJsonFile = "$from/history.json";
            my $historyJson = generateHistoryJson( $historyJsonFile, $releaseTimeStamp );
            UBOS::Utils::writeJsonToFile( $historyJsonFile, $historyJson );

            my $cmd2 = $baseCmd;
            $cmd2 .= " '$historyJsonFile' '$to/history.json'";
            info( "Upload command:", $cmd2 );

            if( UBOS::Utils::myexec( $cmd2, undef, \$out )) {
                error( "$cmd2 failed:", $out );
                $ret = FAIL;
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

## Helper to generate the updated content for a history.json file
# $oldFile: name of the file containing old content (may not exist)
# $releaseTimeStamp: timestamp of the new release
# return: JSON of the new content
sub generateHistoryJson {
    my $historyJsonFile = shift;
    my $releaseTimeStamp = shift;

    my $historyJson;
    if( -e $historyJsonFile ) {
        $historyJson = UBOS::Utils::readJsonFromFile( $historyJsonFile );
    } else {
        $historyJson = {
            'history' => []
        };
    }
    if( $releaseTimeStamp >= 0 ) {
        push @{$historyJson->{history}}, { 'tstamp' => UBOS::Utils::time2rfc3339String( $releaseTimeStamp ) };
    }
    return $historyJson;
}

##
# Helper method to generate an index.html file for a directory
# $dir: the directory
# $title: title for the file
sub generateIndex {
    my $dir   = shift;
    my $title = shift;

    my @files = <$dir/*>;
    @files = grep { ! m/index\.html$/ && ! m/LAST_UPLOADED$/ }
             map { my $x = $_; $x =~ s!.*/!!; $x; } @files;

    my $html = <<HTML;
<html>
 <head>
  <title>$title</title>
 </head>
 <body>
  <h1>$title</h1>
HTML

    if( @files ) {
        $html .= "  <ul>\n";
        for my $file ( @files ) {
            $html .= "   <li>";

            if( -l "$dir/$file" ) {
                my $target = readlink( "$dir/$file" );
                if( $target =~ m!/! ) {
                    $html .= $file; # not safe
                } else {
                    $html .= "$file&nbsp;&nbsp;&nbsp;&nbsp;&#10145;&nbsp;&nbsp;&nbsp;&nbsp;<a href='$target'>$target</a>";
                }
            }  else {
                $html .= "<a href='$file'>$file</a>";
            }
            $html .= "</li>\n";
        }
        $html .= "  </ul>\n";
    } else {
        $html .= "<p>No images currently available.</p>\n";
    }
    $html .= <<HTML;
 </body>
</html>
HTML
    return $html;
}

1;

