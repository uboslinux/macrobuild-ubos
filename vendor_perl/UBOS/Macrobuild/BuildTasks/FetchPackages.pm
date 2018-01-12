#!/usr/bin/perl
#
# Fetches the Arch packages
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::FetchPackages;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db builddir repodir dbSignKey );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
use UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps;
use UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages;
use UBOS::Macrobuild::Utils;

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
    unless( ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUpConfigs = {};
    my $repoUsConfigs = {};

    my @buildTasksSequence = ();

    # create UpConfigs/UsConfigs, and also fetch tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us' );

        my $buildTaskName = "fetch-$shortDb";

        $self->addParallelTask(
                $buildTaskName,
                UBOS::Macrobuild::ComplexTasks::FetchUpdatePackages->new(
                        'name'      => 'Fetch ' . $shortDb . ' packages',
                        'arch'      => '${arch}',
                        'channel'   => '${channel}',
                        'builddir'  => '${builddir}',
                        'repodir'   => '${repodir}',
                        'upconfigs' => $repoUpConfigs->{$shortDb},
                        'db'        => $shortDb,
                        'dbSignKey' => '${dbSignKey}' ));

        push @buildTasksSequence, $buildTaskName;
    }

    $self->setSplitTask( UBOS::Macrobuild::BasicTasks::CheckPossibleOverlaps->new(
            'repoUpConfigs' => $repoUpConfigs,
            'repoUsConfigs' => $repoUsConfigs ));

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge update lists from dev dbs: ' . join( ' ', @$dbs ),
            'keys' => \@buildTasksSequence ));

    return $self;
}

1;
