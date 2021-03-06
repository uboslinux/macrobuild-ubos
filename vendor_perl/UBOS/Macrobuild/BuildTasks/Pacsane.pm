#!/usr/bin/perl
#
# Runs pacsane on the provided DBs
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::Pacsane;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PacsaneRepository;
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

    my @taskNames = ();

    foreach my $db ( @$dbs ) {
        my $shortDb  = UBOS::Macrobuild::Utils::shortDb( $db );
        my $taskName = "pacsane-$shortDb";
        push @taskNames, $taskName;

        $self->addParallelTask(
                $taskName,
                UBOS::Macrobuild::BasicTasks::PacsaneRepository->new(
                        'name'   => 'Pacsane on db ' . $shortDb . ' on ${channel}',
                        'dbfile' => '${repodir}/${channel}/${arch}/' . $shortDb . '/' . $shortDb . '.db.tar.xz' ));
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge pacsane results from repositories: ' . join( ' ', @$dbs ),
            'keys' => \@taskNames ));

    return $self;
}

1;
