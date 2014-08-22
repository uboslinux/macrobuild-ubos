# 
# Config file for upstream packages
#

use strict;
use warnings;

package UBOS::Macrobuild::UpConfig;

use fields qw( name lastModified directory packages );

use UBOS::Utils;
use Macrobuild::Logging;

##
# Constructor
sub new {
    my $self         = shift;
    my $name         = shift;
    my $lastModified = shift;
    my $directory    = shift;
    my $packages     = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}         = $name;
    $self->{lastModified} = $lastModified;
    $self->{directory}    = $directory;
    $self->{packages}     = $packages;

    return $self;
}

##
# Get the name
sub name {
    my $self = shift;

    return $self->{name};
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
# Get the list of packages
sub packages {
    my $self = shift;

    return $self->{packages};
}

##
# Calculate a download URL for a particular package
sub downloadUrlForPackage {
    my $self            = shift;
    my $packageFileName = shift;

    return $self->{directory} . "/$packageFileName";
}

1;
