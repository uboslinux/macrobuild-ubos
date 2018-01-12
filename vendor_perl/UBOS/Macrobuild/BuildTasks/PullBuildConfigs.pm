#!/usr/bin/perl
#
# Updates the buildconfig directories by pulling from git
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::PullBuildConfigs;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( db branch );

use Macrobuild::Task;
use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::PullGit;
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

    # create git pull tasks
    my @pullTaskNames = ();
    foreach my $db ( @$dbs ) {
        my $shortDb      = UBOS::Macrobuild::Utils::shortDb( $db );
        my $pullTaskName = "pull-$shortDb";
        push @pullTaskNames, $pullTaskName;

        $self->addParallelTask(
                $pullTaskName,
                UBOS::Macrobuild::BasicTasks::PullGit->new(
                        'name'   => 'Pull git ' . $db,
                        'dir'    => $db,
                        'branch' => '${branch}' ));
    }
    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name'  => 'Merge update lists from dbLocations: ' . join( ' ', @$dbs ),
            'keys'  => \@pullTaskNames ));

    return $self;
}

1;
