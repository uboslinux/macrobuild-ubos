#!/usr/bin/perl
#
# Run the automated tests
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::RunAutomatedTests;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch builddir channel db repodir testconfig scaffold testplan );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::RunAutomatedWebAppTests;
use UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults;
use UBOS::Macrobuild::UsConfigs;
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

    my $localSourcesDir = $self->getPropertyOrDefault( 'localSourcesDir', undef );

    my $dbs = $self->getProperty( 'db' );
    unless( ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUsConfigs  = {};
    my $repoUpConfigs  = {};
    my @taskNames = ();

    # create tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUpConfigs->{$shortDb} = UBOS::Macrobuild::UpConfigs->allIn( $db . '/up' );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        my $taskName = "run-automated-tests-$shortDb";
        push @taskNames, $taskName;

        $self->addParallelTask(
                $taskName,
                UBOS::Macrobuild::BasicTasks::RunAutomatedWebAppTests->new(
                        'name'      => 'Run automated web app tests with ${testplan} in ' . $db,
                        'arch'      => '${arch}',
                        'usconfigs' => $repoUsConfigs->{$shortDb},
                        'scaffold'  => '${scaffold}', # allows us to filter out directory parameter if not container, for example
                        'config'    => '${testconfig}',
                        'testplan'  => '${testplan}',
                        'directory' => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-container_LATEST.tardir',
                        'sourcedir' => '${builddir}/dbs/' . $shortDb . '/ups' ));
    }

    my $task2 = Macrobuild::CompositeTasks::Sequential->new();
    $task2->appendTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge test results from dbs: ' . join( ' ', @$dbs ),
            'keys' => \@taskNames ));

    $task2->appendTask( UBOS::Macrobuild::BasicTasks::SaveWebAppTestsResults->new(
            'name' => 'Save app tests results' ));

    $self->setJoinTask( $task2 );

    return $self;
}

1;
