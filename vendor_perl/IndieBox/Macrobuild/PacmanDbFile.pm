#!/usr/bin/perl
#
# A pacman DB file
#

use strict;
use warnings;

package IndieBox::Macrobuild::PacmanDbFile;

use Archive::Tar;
use Macrobuild::Logging;
use IndieBox::Utils;

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
        my $tar   = Archive::Tar->new( $self->{filename} );
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
    }

    return $self->{containedPackages};
}

##
sub addPackages {
    my $self     = shift;
    my @packages = @_;
    
    my $packagesString = join( ' ', @packages );

    if( IndieBox::Utils::myexec( "repo-add -q '" . $self->{filename} . "' $packagesString" )) {
        Macrobuild::Logging::error( "Something went wrong when repo-add" );
        return -1;
    }
    return 0;
}


1;

