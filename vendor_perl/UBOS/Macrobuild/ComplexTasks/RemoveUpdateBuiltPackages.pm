#!/usr/bin/perl
#
# Removes packages we built and updates the package database
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch builddir repodir usconfigs db dbSignKey );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::RemoveBuiltPackages;
use UBOS::Macrobuild::BasicTasks::Unstage;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $db = $self->getProperty( 'db' );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::RemoveBuiltPackages->new(
            'name'        => 'Removed built packages on ${channel}',
            'arch'        => '${arch}',
            'usconfigs'   => $self->{usconfigs},
            'sourcedir'   => '${builddir}/dbs/' . $db . '/ups'  ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::Unstage->new(
            'name'        => 'Unstage removed packages in local repository on ${channel}',
            'arch'        => '${arch}',
            'stagedir'    => '${repodir}/${channel}/${arch}/' . $db,
            'dbfile'      => '${repodir}/${channel}/${arch}/' . $db . '/' . $db . '.db.tar.xz',
            'dbSignKey'   => '${dbSignKey}' ));

    return $self;
}

1;
