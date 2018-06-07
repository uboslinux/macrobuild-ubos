#!/usr/bin/perl
#
# Removes packages we built that are marked to be removed
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RemoveBuiltPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch builddir channel repodir localSourcesDir db dbSignKey m2builddir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages;
use UBOS::Macrobuild::UsConfigs;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $m2BuildDir      = $self->getProperty( 'm2builddir' );
    my $localSourcesDir = $self->getPropertyOrDefault( 'localSourcesDir', undef );

    my $dbs = $self->getProperty( 'db' );
    unless( ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUsConfigs   = {};
    my @removeTaskNames = ();

    # create remove packages tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        my $removeTaskName = "remove-$shortDb";
        push @removeTaskNames, $removeTaskName;

        $self->addParallelTask(
                $removeTaskName,
                UBOS::Macrobuild::ComplexTasks::RemoveUpdateBuiltPackages->new(
                        'name'      => 'Remove built packages marked as such from ' . $db . ' on ${channel}',
                        'arch'      => '${arch}',
                        'builddir'  => '${builddir}',
                        'repodir'   => '${repodir}',
                        'usconfigs' => $repoUsConfigs->{$shortDb},
                        'db'        => $shortDb,
                        'dbSignKey' => '${dbSignKey}' ));
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge update lists from dbs: ' . join( ' ', @$dbs ),
            'keys' => \@removeTaskNames ));

    return $self;
}

1;
