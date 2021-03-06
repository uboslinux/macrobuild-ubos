#!/usr/bin/perl
#
# Removes packages fetched from upstream marked to be removed
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RemoveFetchedPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch builddir channel repodir db dbSignKey );

use Macrobuild::Task;
use Macrobuild::BasicTasks::MergeValues;
use UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages;
use UBOS::Macrobuild::UpConfigs;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $dbs = $self->getProperty( 'db' );
    if( !ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUpConfigs = {};

    my @removeTaskNames = ();
    foreach my $db ( @$dbs ) {
        my $shortDb  = UBOS::Macrobuild::Utils::shortDb( $db );
        my $taskName = "remove-fetched-packages-$shortDb";
        push @removeTaskNames, $taskName;

        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );

        $self->addParallelTask(
                $taskName,
                UBOS::Macrobuild::ComplexTasks::RemoveUpdateFetchedPackages->new(
                        'name'      => 'Remove fetched packages marked as such from ' . $db . ' on ${channel}',
                        'arch'      => '${arch}',
                        'builddir'  => '${builddir}',
                        'repodir'   => '${repodir}',
                        'upconfigs' => $repoUpConfigs->{$shortDb},
                        'db'        => $shortDb,
                        'dbSignKey' => '${dbSignKey}' ));
   }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge update lists from dbs: ' . join( ' ', @$dbs ),
            'keys' => \@removeTaskNames ));

    return $self;
}

1;
