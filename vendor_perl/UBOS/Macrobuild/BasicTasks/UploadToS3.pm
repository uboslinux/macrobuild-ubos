#!/usr/bin/perl
#
# Upload something to Amazon S3, which hosts the depot. Also generates
# an index.html for the /images directories.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UploadToS3;

use base qw( Macrobuild::Task );
use fields qw( arch from to inexclude );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch = $self->getProperty( 'arch' );
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

            if( -d "$from/images" ) {
                UBOS::Utils::saveFile( "$from/images/index.html", _generateIndex( "$from/images", "Index of $arch images" ));
            }

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

##
# Helper method to generate an index.html file for a directory
# $dir: the directory
# $title: title for the file
sub _generateIndex {
    my $dir   = shift;
    my $title = shift;

    my @files = <$dir/*>;
    @files = grep { ! m/index\.html$/ }
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

