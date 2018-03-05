#!/usr/bin/perl
#
# Check that the versions of the packages in a channel correspond to
# the versions in the PKGBUILDs.
#
# Copyright (C) 2018 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::ComparePkgver;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel builddir repodir db );

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

    my $localSourcesDir = $self->getPropertyOrDefault( 'localSourcesDir', undef );

    my $dbs = $self->getProperty( 'db' );
    unless( ref( $dbs )) {
        $dbs = [ $dbs ];
    }

    my $repoUsConfigs  = {};
    my @compareTaskNames = ();

    # create compare tasks
    foreach my $db ( @$dbs ) {
        my $shortDb = UBOS::Macrobuild::Utils::shortDb( $db );
        $repoUsConfigs->{$shortDb} = UBOS::Macrobuild::UsConfigs->allIn( $db . '/us', $localSourcesDir );

        my $compareTaskName = "compare-$shortDb";
        push @compareTaskNames, $compareTaskName;

        $self->addParallelTask(
                $compareTaskName,
                UBOS::Macrobuild::BasicTasks::ComparePkgver->new(
                        'name'           => 'Compare pkgver between PKGBUILD and package in ' . $db,
                        'arch'           => '${arch}',
                        'builddir'       => '${builddir}',
                        'repodir'        => '${repodir}',
                        'usconfigs'      => $repoUsConfigs->{$shortDb},
                        'db'             => $shortDb );
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge check lists from dev dbs: ' . join( ' ', @$dbs ),
            'keys' => \@compareTaskNames ));

    return $self;
}

1;
