# 
# Set up maven ready for building package for UBOS
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::SetupMaven;

use base qw( Macrobuild::Task );
use fields qw( m2builddir cleanFirst );

use Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );

    my $ret = 1;

    if( defined( $self->{m2builddir} )) {
        my $m2BuildDir = $run->replaceVariables( $self->{m2builddir} );

        unless( -d $m2BuildDir ) {
            if( -e $m2BuildDir ) {
                error( 'Cannot create directory', $m2BuildDir, ', something else is in the way' );
                $ret = -1;

            } elsif( UBOS::Utils::mkdirDashP( $m2BuildDir )) {
                $ret = 0;

            } else {
                error( 'Failed to create directory', $m2BuildDir );
                $ret = -1;
            }
        }
        if( -d $m2BuildDir ) {
            if( !defined( $self->{cleanFirst} ) || $self->{cleanFirst} ) {
                if( opendir( DIR, $m2BuildDir )) {
                    my @files = ();

                    while( my $file = readdir( DIR )) {
                        if( $file eq '.' || $file eq '..' ) {
                            next;
                        }
                        push @files, "$m2BuildDir/$file";
                    }
                    closedir( DIR );

                    if( @files && !UBOS::Utils::deleteRecursively( @files )) {
                        $ret = -1;
                    }

                } else {
                    error( 'Cannot read directory', $m2BuildDir );
                    $ret = -1;
                }
                
                # write settings.xml file
                if( UBOS::Utils::saveFile( "$m2BuildDir/settings.xml", <<CONTENT )) {
<?xml version="1.0" encoding="UTF-8"?>

<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">

  <localRepository>$m2BuildDir/repository</localRepository>

  <interactiveMode>false</interactiveMode>

<!--
  <offline>true</offline>
-->
  <offline>false</offline>

</settings>
CONTENT
                    $ret = 0;

                } else {
                    error( 'Cannot write Maven settings file', "$m2BuildDir/settings.xml" );
                    $ret = -1;
                }
            }
        }
    }

    $run->taskEnded(
            $self,
            {},
            $ret );

    return $ret;
}

1;

