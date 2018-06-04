#!/usr/bin/perl
#
# Pulls packages, builds them, and updates the package database
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::PullBuildUpdatePackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch builddir repodir usconfigs db dbSignKey m2settingsfile m2repository );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::BuildPackages;
use UBOS::Macrobuild::BasicTasks::PullSources;
use UBOS::Macrobuild::BasicTasks::Stage;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $db        = $self->getProperty( 'db' );
    my $usconfigs = $self->getProperty( 'usconfigs' );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::PullSources->new(
            'name'           => 'Pull the sources that need to be built for db ' . $db,
            'usconfigs'      => $usconfigs,
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups'  ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::BuildPackages->new(
            'name'           => 'Building packages locally for db ' . $db,
            'arch'           => '${arch}',
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups',
            'stopOnError'    => 0,
            'm2settingsfile' => '${m2settingsfile}',
            'm2repository'   => '${m2repository}' ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
            'name'           => 'Stage new packages in local repository for db ' . $db,
            'arch'           => '${arch}',
            'usconfigs'      => $usconfigs,
            'sourcedir'      => '${builddir}/dbs/' . $db . '/ups',
            'stagedir'       => '${repodir}/${channel}/${arch}/' . $db,
            'dbfile'         => '${repodir}/${channel}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
            'dbSignKey'      => '${dbSignKey}' ));

    return $self;
}

1;
