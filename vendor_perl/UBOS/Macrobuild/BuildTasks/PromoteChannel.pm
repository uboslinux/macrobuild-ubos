#!/usr/bin/perl
#
# Promotes one channel to another.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PromoteChannel;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db repodir fromChannel );

use Macrobuild::Task;
use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::Report;
use UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository;
use UBOS::Macrobuild::UpConfigs;
use UBOS::Macrobuild::UsConfigs;
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

    my @promoteTasks = ();

    # create UpConfigs/UsConfigs, and also fetch tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us' );

        my $promoteTaskName = "promote-$shortDb";

        $self->addParallelTask(
                $promoteTaskName,
                UBOS::Macrobuild::ComplexTasks::PromoteChannelRepository->new(
                        'name'        => 'Promote channel repository ' . $shortDb . ' from ${fromChannel} to ${channel}',
                        'arch'        => '${arch}',
                        'channel'     => '${channel}',
                        'upconfigs'   => $repoUpConfigs->{$shortDb},
                        'usconfigs'   => $repoUsConfigs->{$shortDb},
                        'db'          => $shortDb,
                        'repodir'     => '${repodir}',
                        'fromChannel' => '${fromChannel}' ));

        push @promoteTasks, $promoteTaskName;
    }

    my $mergeAndReport = Macrobuild::CompositeTasks::Sequential->new(
            'name' => 'Merge and report' );

    $mergeAndReport->appendTask(
            Macrobuild::BasicTasks::MergeValues->new(
                    'name' => 'Merge promotion lists from repositories: ' . join( ' ', @$dbs ),
                    'keys' => \@promoteTasks ));

    $mergeAndReport->appendTask(
            UBOS::Macrobuild::BasicTasks::Report->new(
                    'name' => 'Report on ' . ref( $self )));

    $self->setJoinTask( $mergeAndReport );

    return $self;
}

1;
