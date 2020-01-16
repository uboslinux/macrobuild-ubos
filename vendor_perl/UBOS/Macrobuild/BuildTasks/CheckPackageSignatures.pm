#!/usr/bin/perl
#
# Check that all packages in a channel have
# corresponding signature files.
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckPackageSignatures;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel db repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::SplitJoin;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::CheckSignatures;

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

    my @checkTaskNames = ();
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );

        my $checkTaskName = "check-signatures-$shortDb";

        $self->addParallelTask(
                $checkTaskName,
                UBOS::Macrobuild::BasicTasks::CheckSignatures->new(
                        'name'  => 'Check signatures for ' . $db . ' on ${channel}',
                        'dir'   => '${repodir}/${channel}/${arch}/' . $shortDb,
                        'glob'  => '*.pkg.tar.{xz,gz,lz4,zst}' ));

        push @checkTaskNames, $checkTaskName;
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge results from ${channel} dbs: ' . join( ' ', @$dbs ),
            'keys' => \@checkTaskNames ));

    return $self;
}

1;
