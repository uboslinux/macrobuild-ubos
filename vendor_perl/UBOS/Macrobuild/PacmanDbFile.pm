#!/usr/bin/perl
#
# A pacman DB file
#

use strict;
use warnings;

package UBOS::Macrobuild::PacmanDbFile;

use Archive::Tar;
use UBOS::Logging;
use UBOS::Utils;

use fields qw( filename containedPackages );

##
# $name: short repository name
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
sub fileName {
    my $self = shift;

    return $self->{filename};
}

##
sub containedPackages {
    my $self = shift;

    unless( $self->{containedPackages} ) {
        my $tar = Archive::Tar->new( $self->{filename} );
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
            error( 'Failed to read tar file, skipping', $self->{filename} );
            next;
        }
    }

    return $self->{containedPackages};
}

##
sub addPackages {
    my $self      = shift;
    my $dbSignKey = shift;
    my $packages  = shift;
    
    my $cmd = 'repo-add';
    unless( UBOS::Logging::isDebugActive() ) {
        $cmd .= ' --quiet';
    }
    if( defined( $dbSignKey )) {
		$cmd .= ' --sign --key ' . $dbSignKey;
	}
	$cmd .= " '" . $self->{filename} . "'";
	$cmd .= ' ' . join( ' ', @$packages );

    my $result;
    if( UBOS::Logging::isInfoActive() ) {
        $result = UBOS::Utils::myexec( $cmd );
    } else {
        my $out;
        $result = UBOS::Utils::myexec( $cmd, undef, \$out );
    }
    if( $result ) {
        error( 'Something went wrong when executing:', $cmd, " -- env was:\n" . join( "\n", map { "$_ => " . $ENV{$_} } keys %ENV ));
        return -1;
    }
    return 0;
}


1;

