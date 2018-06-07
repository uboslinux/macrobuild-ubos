#!/usr/bin/perl
#
# Fetches packages from Arch and updates the package database
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel builddir repodir upconfigs db dbSignKey );

use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::DownloadPackageDbs;
use UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir;
use UBOS::Macrobuild::BasicTasks::FetchPackages;
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
    my $upconfigs = $self->getProperty( 'upconfigs' );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::DownloadPackageDbs->new(
            'name'        => 'Download package database files from Arch',
            'upconfigs'   => $upconfigs,
            'downloaddir' => '${builddir}/dbs/' . $db . '/upc' ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::DetermineChangedPackagesFromDbAndDir->new(
            'name'        => 'Determining which packages changed in Arch on ${channel}',
            'upconfigs'   => $upconfigs,
            'dir'         => '${builddir}/dbs/' . $db . '/upc',
            'channel'     => '${channel}',
            'arch'        => '${arch}' ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::FetchPackages->new(
            'name'        => 'Fetching packages downloaded from Arch on ${channel}',
            'downloaddir' => '${builddir}/dbs/' . $db . '/upc' ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::Stage->new(
            'name'        => 'Stage fetched packages in local repository for db ' . $self->{db} . ' on ${channel}',
            'arch'        => '${arch}',
            'upconfigs'   => $upconfigs,
            'sourcedir'   => '${builddir}/dbs/' . $db . '/upc',
            'stagedir'    => '${repodir}/${channel}/${arch}/' . $db,
            'dbfile'      => '${repodir}/${channel}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
            'dbSignKey'   => '${dbSignKey}' ));

    return $self;
}

1;
