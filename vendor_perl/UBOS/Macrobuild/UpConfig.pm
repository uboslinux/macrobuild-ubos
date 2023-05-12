#!/usr/bin/perl
#
# Config file for upstream packages
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::UpConfig;

use fields qw( name overlapBucket lastModified directory packages removePackages );

use UBOS::Logging;
use UBOS::Utils;

##
# Constructor
sub new {
    my $self           = shift;
    my $name           = shift;
    my $configJson     = shift;
    my $lastModified   = shift;
    my $directory      = shift;
    my $packages       = shift;
    my $removePackages = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}           = $name;
    $self->{lastModified}   = $lastModified;
    $self->{directory}      = $directory;
    $self->{packages}       = $packages;
    $self->{removePackages} = $removePackages;

    if( exists( $configJson->{'overlap-bucket'} )) {
        $self->{overlapBucket} = $configJson->{'overlap-bucket'};
    } else {
        $self->{overlapBucket} = 'ubos';
    }
    trace( 'UpConfig:', $name, 'mod:', $lastModified, 'in directory:', $directory, 'packages:', sort keys %$packages, 'remove:', sort keys %$removePackages );

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
# Determine when this config was last modified
sub lastModified {
    my $self = shift;

    return $self->{lastModified};
}

##
# Get the directory
sub directory {
    my $self = shift;

    return $self->{directory};
}

##
# Get the set of packages, keyed by package name
sub packages {
    my $self = shift;

    return $self->{packages};
}

##
# Determine whether this UpConfig contains this package.
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
# Calculate a download URL for a particular package
sub downloadUrlForPackage {
    my $self            = shift;
    my $packageFileName = shift;

    return $self->{directory} . "/$packageFileName";
}

1;
