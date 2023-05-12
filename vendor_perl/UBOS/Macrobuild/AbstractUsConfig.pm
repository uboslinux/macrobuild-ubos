#!/usr/bin/perl
#
# Abstract supertype for various implementations of config files for upstream sources
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::AbstractUsConfig;

use fields qw( name overlapBucket url file packages removePackages webapptests );

use UBOS::Logging;
use UBOS::Utils;

##
# Constructor
sub new {
    my $self            = shift;
    my $name            = shift;
    my $configJson      = shift;
    my $file            = shift;
    my $localSourcesDir = shift;
    my $packages        = shift;
    my $removePackages  = shift;
    my $webapptests     = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    unless( defined( $name )) {
        fatal( 'No name provided for usConfig', $file, ':', $name );
    }
    unless( $name =~ m!^[-_a-z0-9]+$! ) {
        fatal( 'Invalid name for usConfig', $file, ':', $name );
    }
    unless( defined( $configJson->{url} )) {
        fatal( 'No url field defined in usConfig', $file, ':', $configJson->{url} );
    }
    unless( $configJson->{url} =~ m!^[a-z]+://.*$! ) {
        fatal( 'Invalid url field in usConfig', $file, ':', $configJson->{url} );
    }

    if( exists( $configJson->{'overlap-bucket'} )) {
        $self->{overlapBucket} = $configJson->{'overlap-bucket'};
    } else {
        $self->{overlapBucket} = 'ubos';
    }

    $self->{name}           = $name;
    $self->{file}           = $configJson->{file};
    $self->{packages}       = $packages;
    $self->{removePackages} = $removePackages;
    $self->{webapptests}    = $webapptests;

    if( defined( $localSourcesDir )) {
        # use already-exising local copy instead
        my $withoutProto = $configJson->{url};
        $withoutProto =~ s!^(https?|ftp)://!!;
        $self->{url} = "$localSourcesDir/$withoutProto";
    } else {
        $self->{url} = $configJson->{url};
    }

    trace( ref( $self ) . ':', $name, 'sources dir:', $localSourcesDir, 'packages:', join( ' ', sort keys %$packages ), 'remove:', join( ' ', sort keys %$removePackages ));

    return $self;
}

##
# Get the name
sub name {
    my $self = shift;

    return $self->{name};
}

##
# Return a string that defines the scope in which possible package overlap is
# analyzed.
sub overlapBucket {
    my $self = shift;

    return $self->{overlapBucket};
}

##
# Get the type
sub type {
    my $self = shift;

    fatal( 'Must override', ref( $self ));
}

##
# Get the url
sub url {
    my $self = shift;

    return $self->{url};
}

##
# Get the set of packages, keyed by package name
sub packages {
    my $self = shift;

    return $self->{packages};
}

##
# Determine whether this UsConfig contains this package.
# $candidatePackage: name of the package
# return: def or undef
sub containsPackage {
    my $self             = shift;
    my $candidatePackage = shift;

    if( exists( $self->{packages}->{$candidatePackage} )) {
        return $self->{packages}->{$candidatePackage};
    } else {
        return undef;
    }
}

##
# Get the set of packages to be removed, keyed by package name
sub removePackages {
    my $self = shift;

    return $self->{removePackages};
}

##
# Get a list of webapptests
sub webapptests {
    my $self = shift;

    return $self->{webapptests};
}

1;
