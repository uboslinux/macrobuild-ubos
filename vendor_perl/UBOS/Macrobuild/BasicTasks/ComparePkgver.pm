#!/usr/bin/perl
#
# Checks PKGBUILD's pkgver against version of built packages
#
# Copyright (C) 2018 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::ComparePkgver;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch builddir repodir usconfigs db );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::BuildPackages;
use UBOS::Macrobuild::BasicTasks::PullSources;
use UBOS::Macrobuild::BasicTasks::Stage;
use UBOS::Macrobuild::BasicTasks::UpdatePackageDatabase;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );


    my $usConfigs = $self->{usconfigs}->configs( $self );
    unless( $usConfigs ) {
        return FAIL;
    }
    my $ok = 1;
    foreach my $repoName ( sort keys %$usConfigs ) { # make predictable sequence
        my $usConfig = $usConfigs->{$repoName};

        info( "Looking at ", $usConfig->name );

    }

    return $self;
}

1;
