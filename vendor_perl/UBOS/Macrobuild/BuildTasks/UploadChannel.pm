#!/usr/bin/perl
#
# Uploads a locally staged channel
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadChannel;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel repodir uploadDest subdir uploadInExclude genindextitle );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::Upload;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( @args );

    my $subdirs = $self->getProperty( 'subdir' );
    if( !ref( $subdirs )) {
        $subdirs = [ $subdirs ];
    }

    my @uploadTaskNames = ();
    foreach my $subdir ( @$subdirs ) {
        my $taskName = "upload-$subdir";
        push @uploadTaskNames, $taskName;

        $self->addParallelTask(
                $taskName,
                UBOS::Macrobuild::BasicTasks::Upload->new(
                        'name'             => 'Upload subdir ' . $subdir . ' on ${channel}',
                        'from'             => '${repodir}/${channel}/${arch}/' . $subdir,
                        'to'               => '${uploadDest}/${arch}/' . $subdir,
                        'inexclude'        => '${uploadInExclude}',
                        'genindextitle'    => '${genindextitle}',
                        'releasetimestamp' => '${releaseTimeStamp}' ));
    }

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge upload results from subdirs: ' . join( ' ', @$subdirs ),
            'keys' => \@uploadTaskNames ));
    return $self;
}

1;
